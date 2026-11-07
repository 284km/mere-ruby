# frozen_string_literal: true
#
# StringScanner, as mere-ruby answers `require "strscan"` (ruby's is a C
# extension, ext/strscan). Written here in Ruby over the String it scans;
# every method was measured against the reference. Shipped through
# tools/gen_pathname_lib.rb.
class StringScanner
  # the reference's version: specs choose their examples by it
  # (`version_is StringScanner::Version, "3.1.1"`), and a missing
  # constant killed the whole file before one example ran
  Version = "3.1.6".freeze
  Id = "$Id$"
  attr_reader :string

  def initialize(string, _dup = false, fixed_anchor: false)
    # ⚠ #to_str, not #to_s. `to_s` accepts ANY object and turns it into its
    #   inspect form, so `StringScanner.new(obj)` scanned the text
    #   "#<Obj:0x...>" instead of refusing -- a wrong argument became a
    #   plausible subject.
    unless string.is_a?(String)
      unless string.respond_to?(:to_str)
        raise TypeError, "no implicit conversion of " + string.class.to_s + " into String"
      end
      string = string.to_str
    end
    @string = string
    __measure
    @pos = 0
    @cp = 0
    @matched = nil
    @md = nil
    @prev_pos = 0
    @prev_cp = 0
    @fixed = fixed_anchor ? true : false
  end

  # ⚠ THE POINTER IS A BYTE OFFSET, as ruby's is. It counted characters, with
  #   the byte view computed at #pos and #pos= -- and a byte offset inside a
  #   character is exactly what that model cannot hold: `pos = 1` on "∂"
  #   refused with RangeError, and scan_byte through "あ" consumed the whole
  #   character at once (227, then nil). ruby's scanner is a byte cursor
  #   that also knows the character index when it is on a boundary.
  #   So @pos is the bytes and @cp the characters, kept in step as a match
  #   advances; @cp is nil while the pointer sits inside a character (after
  #   #pos= or a byte read), and is worked out again when it is asked for.
  #   The matching engine takes a CHARACTER position, which is why @cp
  #   exists: matching in place at it is the fast path (see __at).
  # the subject does not change while it is being scanned, and String#length
  # walks the whole string, so ask once (and again when #concat grows it).
  def __measure
    @len = @string.length
    @blen = @string.bytesize
  end
  private :__measure

  # (the subject may be replaced behind the scanner's back -- `s.string
  #  .replace("")` -- so the byte length is read live and the character
  #  length measured again when the bytes changed)
  def __sync
    __measure if @blen != @string.bytesize
  end
  private :__sync

  # StringScanner.allocate has no subject yet: ruby refuses to scan it
  def __init_check
    raise ArgumentError, "uninitialized StringScanner object" if @string.nil?
  end
  private :__init_check

  # the character index of the pointer, nil when it is inside a character
  def __cp
    return @cp if @cp
    __sync
    head = @string.byteslice(0, @pos)
    tail = @string.byteslice(@pos, @blen - @pos)
    # a boundary splits no character: the two halves count what the whole does
    @cp = head.length if head.length + tail.length == @len
    @cp
  end
  private :__cp

  def pos
    @pos
  end
  alias_method :pointer, :pos

  def pos=(n)
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    n += @blen if n < 0
    raise RangeError, "index out of range" if n < 0 || n > @blen
    @pos = n
    @cp = nil
    n
  end
  alias_method :pointer=, :pos=

  # (inside a character it counts the partial one, as the reference does)
  def charpos
    __cp || @string.byteslice(0, @pos).length
  end

  def reset
    @pos = 0
    @cp = 0
    @matched = nil
    @md = nil
    self
  end

  def terminate
    @pos = @blen
    @cp = @len
    @matched = nil
    @md = nil
    self
  end

  def eos?
    __init_check
    @pos >= @string.bytesize
  end

  def rest
    __init_check
    @string.byteslice(@pos, @string.bytesize - @pos) || ""
  end

  # ruby: "rest_size is equivalent to rest.bytesize"
  def rest_size
    @string.bytesize - @pos
  end

  def matched
    @matched
  end

  def matched?
    !@matched.nil?
  end

  def matched_size
    @matched.nil? ? nil : @matched.bytesize
  end

  # both nil until something matched, and both measured from the match
  # itself -- after #check the pointer has not moved but the match has
  def pre_match
    return nil if @matched.nil?
    @string.byteslice(0, @mstart)
  end

  def post_match
    return nil if @matched.nil?
    @string.byteslice(@mend, @blen - @mend)
  end

  # \G, not \A: the match happens AT the pointer inside the whole subject.
  # With \A the pattern could only be tried against a fresh string, which
  # is what `rest` was for -- and `rest` copies everything left to scan, so
  # one scan per token over an N-byte input was O(N^2). CSV.parse on quoted
  # input spent 6.2 s on 400 rows and 49 s on 1200 because of this.
  # ⚠ WITH THE PATTERN'S OWN FLAGS: rebuilding it from #source alone
  #   dropped /i, /m and /x, so `scan(/ab/i)` failed on "AB".
  # The rebuilt pattern is kept per pattern -- compiling it on every token
  # was the other half of the cost above.
  def anchored(re)
    @__anch ||= {}
    @__anch[re] ||= Regexp.new(__src_in(re, "\\G(?:" + re.source + ")"), re.options)
  end
  private :anchored

  # (a pattern with a fixed encoding -- `/./e` -- keeps it when it is
  #  rewritten with an anchor: the source carries the encoding)
  def __src_in(re, src)
    re.fixed_encoding? ? src.dup.force_encoding(re.encoding) : src
  end
  private :__src_in

  # a pattern is a Regexp or a String (matched as itself); nothing else
  def __pat(re)
    return re if re.is_a?(Regexp)
    return Regexp.new(Regexp.escape(re)) if re.is_a?(String)
    raise TypeError, "no implicit conversion of " + (re.nil? ? "nil" : re.class.to_s) + " into String"
  end
  private :__pat

  # Without fixed_anchor (the default), \A, ^ and a look-behind see the scan
  # pointer as the start of the string: such a pattern is tried against the
  # rest. So is any pattern while the pointer is inside a character, where
  # there is no character position to match at. Everything else matches in
  # place, which is what fixed_anchor means and is the fast path.
  def __on_rest?(re)
    return true if __cp.nil?
    !@fixed && (re.source.include?("\\A") || re.source.include?("^") || re.source.include?("(?<"))
  end
  private :__on_rest?

  # The match of `re` at the pointer (`anchor`) or anywhere after it, as
  # [MatchData, byte start, byte end, character end or nil]; nil for none.
  def __at(re, anchor)
    __init_check
    __sync
    re = __pat(re)
    if __on_rest?(re)
      @__rest ||= {}
      key = [re, anchor]
      r2 = (@__rest[key] ||= anchor ? Regexp.new(__src_in(re, "\\A(?:" + re.source + ")"), re.options) : re)
      m = r2.match(rest)
      return nil if m.nil?
      bs, be = m.byteoffset(0)
      # a string whose characters are all one byte counts the end in
      # bytes: MatchData#end on the fresh rest walked all of it, per scan
      [m, @pos + bs, @pos + be, @cp && (@cp + (@len == @blen ? be : m.end(0)))]
    else
      m = (anchor ? anchored(re) : re).match(@string, @cp)
      return nil if m.nil?
      bs, be = m.byteoffset(0)
      [m, bs, be, m.end(0)]
    end
  end
  private :__at

  # A regexp match took place: it is the last match, whatever the pattern
  # was written as -- but only a Regexp has groups to name (@rx).
  def __took(hit, re, advance)
    m, bs, be, ce = hit
    @md = m
    @rx = re.is_a?(Regexp)
    @matched = m[0]
    @mstart = bs
    @mend = be
    if advance
      @prev_pos = @pos
      @prev_cp = @cp
      @pos = be
      @cp = ce
    end
  end
  private :__took

  def __miss
    @md = nil
    @matched = nil
  end
  private :__miss

  def scan(re)
    hit = __at(re, true)
    return __miss if hit.nil?
    __took(hit, re, true)
    @matched
  end

  def check(re)
    hit = __at(re, true)
    return __miss if hit.nil?
    __took(hit, re, false)
    @matched
  end

  def match?(re)
    hit = __at(re, true)
    return __miss if hit.nil?
    __took(hit, re, false)
    @matched.bytesize
  end

  def skip(re)
    s = scan(re)
    s.nil? ? nil : s.bytesize
  end

  # A one-character (or one-byte) read is a match too -- of that text, with
  # no groups: `s[0]` is what it read and `s[:name]` is refused.
  def __took_text(t)
    @md = nil
    @rx = false
    @prev_pos = @pos
    @prev_cp = @cp
    @matched = t
    @mstart = @pos
    @pos += t.bytesize
    @mend = @pos
  end
  private :__took_text

  # The groups of the last match, by index or by name (a lexer built on
  # StringScanner reads its groups this way). After a match that was not a
  # Regexp's -- a String pattern, getch, get_byte -- there is one group, the
  # matched text, and no names: ruby refuses a name then (IndexError).
  def [](i)
    return nil if @matched.nil?
    if i.is_a?(Symbol) || i.is_a?(String)
      raise IndexError, "undefined group name reference: #{i}" unless @rx && @md.names.include?(i.to_s)
      return @md[i]
    end
    i = StringScanner.__idx(i)
    if @rx
      i += @md.size if i < 0
      return i < 0 ? nil : @md[i]
    end
    (i == 0 || i == -1) ? @matched : nil
  end
  def self.__idx(i)
    return i if i.is_a?(Integer) || i.is_a?(String) || i.is_a?(Symbol)
    unless i.respond_to?(:to_int)
      raise TypeError, "no implicit conversion of " + i.class.to_s + " into Integer"
    end
    i.to_int
  end
  def captures
    return nil if @matched.nil?
    @rx ? @md.captures : []
  end
  def values_at(*ix)
    return nil if @matched.nil?
    ix.map do |i|
      self[StringScanner.__idx(i)]
    end
  end
  def size
    return nil if @matched.nil?
    @rx ? @md.size : 1
  end

  # --- searching ----------------------------------------------------------
  # the shared worker: everything from the pointer through the END of the
  # first match of `re`, leaving the pointer there. The span comes from the
  # MatchData rather than from `r.index(m[0])`, which found the FIRST
  # occurrence of the matched text, not the position it was matched at.
  def __search(re)
    hit = __at(re, false)
    return __miss if hit.nil?
    start = @pos
    __took(hit, re, true)
    @string.byteslice(start, @pos - start)
  end
  private :__search

  def scan_until(re)
    __search(re)
  end

  def skip_until(re)
    s = scan_until(re)
    s.nil? ? nil : s.bytesize
  end

  def check_until(re)
    saved = [@pos, @cp]
    r = __search(re)
    @pos, @cp = saved
    r
  end

  def exist?(re)
    saved = [@pos, @cp]
    r = __search(re)
    @pos, @cp = saved
    r.nil? ? nil : r.bytesize
  end

  # one CHARACTER of the subject's own encoding (a byte, inside one)
  def getch
    return nil if eos?
    cp = __cp
    c = cp ? @string[cp, 1] : @string.byteslice(@pos, 1)
    return nil if c.nil? || c.empty?
    __took_text(c)
    @cp = cp && cp + 1
    @matched
  end

  # BYTES, as ruby counts them: peek(1) of "é" is "\xC3"
  def peek(n)
    n = n.to_int unless n.is_a?(Integer)
    raise ArgumentError, "negative string size (or size too big)" if n < 0
    @string.byteslice(@pos, n) || ""
  end

  def unscan
    # ⚠ UNSCAN NEEDS A MATCH TO UNDO. This reset the position whether or not
    #   there was one, so a second unscan silently moved the scanner again
    #   -- the record it was undoing had already been consumed.
    if @matched.nil?
      raise StringScanner::Error, "unscan failed: previous match record not exist"
    end
    @pos = @prev_pos
    @cp = @prev_cp
    @matched = nil
    @md = nil
    self
  end

  # ⚠ ruby's #inspect SAYS WHERE THE SCANNER IS -- position, length, what was
  #   just matched and what is ahead -- and this answered a constant
  #   "#<StringScanner>" for every scanner in every state. It is the first
  #   thing anyone debugging a scan looks at.
  #   The shapes, asked of the reference: "fin" at the end, "p/len @ ahead"
  #   before any match, and "p/len matched @ ahead" after one. The two texts
  #   are clipped to five characters with an ellipsis.
  # ⚠ the part BEFORE the pointer is up to five characters of the
  # STRING, not the last match: `scan_until(/is/)` from 0 shows "This",
  # and a pointer moved by #pos= with nothing matched shows its left
  # context too. Only at 0 is it left out.
  def inspect
    return "#<StringScanner (uninitialized)>" if @string.nil?
    return "#<StringScanner fin>" if eos?
    r = rest
    ahead = r[0, 5].inspect
    ahead = ahead[0...-1] + "...\"" if r.length > 5
    head = "#<StringScanner " + @pos.to_s + "/" + @string.bytesize.to_s
    return head + " @ " + ahead + ">" if @pos == 0
    before = @string.byteslice(0, @pos)
    back = before.length > 5 ? before[-5, 5] : before
    shown = back.inspect
    shown = "\"..." + shown[1..-1] if before.length > 5
    head + " " + shown + " @ " + ahead + ">"
  end

  # --- the names the reference has and this did not ----------------------
  def concat(str)
    unless str.is_a?(String) || str.respond_to?(:to_str)
      raise TypeError, "no implicit conversion of #{str.class} into String"
    end
    @string << str.to_str
    __measure
    self
  end
  alias_method :<<, :concat

  def string=(str)
    str = str.to_str if !str.is_a?(String) && str.respond_to?(:to_str)
    raise TypeError, "no implicit conversion into String" unless str.is_a?(String)
    @string = str
    __measure
    reset
    str
  end

  def beginning_of_line?
    return true if @pos == 0
    return nil if @pos > @string.bytesize
    @string.getbyte(@pos - 1) == 10
  end
  alias_method :bol?, :beginning_of_line?

  def rest?
    !eos?
  end

  def fixed_anchor?
    @fixed
  end

  # --- the byte-at-a-time readers ----------------------------------------
  # `get_byte` answers a STRING and `scan_byte` answers the byte's INTEGER
  # value, though they consume the same byte -- so scan_byte is not an alias.
  # `peek_byte` is the integer too, and consumes nothing.
  def get_byte
    return nil if eos?
    b = @string.byteslice(@pos, 1)
    return nil if b.nil? || b.empty?
    cp = @cp
    __took_text(b)
    # still on a boundary after an ASCII byte; otherwise worked out on demand
    @cp = (cp && b.getbyte(0) < 128) ? cp + 1 : nil
    b
  end

  def scan_byte
    b = get_byte
    b.nil? ? nil : b.getbyte(0)
  end

  def peek_byte
    return nil if eos?
    @string.getbyte(@pos)
  end

  # --- the *_full family: one call, four answers -------------------------
  def scan_full(re, advance = true, ret_string = true)
    saved = [@pos, @cp]
    m = scan(re)
    return nil if m.nil?
    n = m.bytesize
    @pos, @cp = saved unless advance
    ret_string ? m : n
  end

  def search_full(re, advance = true, ret_string = true)
    saved = [@pos, @cp]
    r = __search(re)
    return nil if r.nil?
    n = r.bytesize
    @pos, @cp = saved unless advance
    ret_string ? r : n
  end

  def named_captures
    (@md.nil? || !@rx) ? {} : @md.named_captures
  end

  # ruby 3.4's scan_integer: an optional sign then digits, consumed only if
  # the whole thing is there; base 16 also accepts the 0x prefix. Those are
  # the only two bases, and the subject has to be ASCII-compatible text.
  def scan_integer(base: 10)
    re =
      case base
      when 10 then /[+-]?\d+/
      when 16 then /[+-]?(0x)?[0-9a-fA-F]+/
      else raise ArgumentError, "Unsupported integer base: #{base.inspect}, expected 10 or 16"
      end
    unless @string.encoding.ascii_compatible?
      raise Encoding::CompatibilityError, "ASCII incompatible encoding: #{@string.encoding.name}"
    end
    m = scan(re)
    return nil if m.nil?
    Integer(m, base)
  end

  def self.must_C_version
    self
  end

end
StringScanner::Error = Class.new(StandardError)
