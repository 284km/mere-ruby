# frozen_string_literal: true
# A Ruby stand-in for CRuby's ext/-test-/file, which an installed ruby does not
# carry: test_file, test_file_exhaustive and test_dir_m17n require it, and
# without it neither side runs a single one of their tests. unittest/run.sh
# puts this directory on the load path of BOTH sides, so what it answers is
# part of the instrument, as mspec's shim is -- it must not decide a verdict.
module Bug
  module File
    # fs.c: statfs(2)'s f_fstypename and the noatime flag, read here from
    # mount(8): the longest mount point that contains the path.
    module Fs
      def self.__mount_of(path)
        full = ::File.expand_path(path)
        best = nil
        `mount`.each_line do |l|
          next unless (m = l.match(/ on (.+) \(([^)]*)\)\s*\z/) || l.match(/ on (.+) type (\S+) \(([^)]*)\)\s*\z/))
          point = m[1]
          inside = point == "/" || full == point || full.start_with?(point + "/")
          next unless inside
          best = m if best.nil? || point.size > best[1].size
        end
        best
      end
      def self.fsname(path)
        m = __mount_of(path)
        return nil unless m
        m.size == 4 ? m[2] : m[2].split(",").first.strip
      end
      def self.noatime?(path)
        m = __mount_of(path)
        return false unless m
        opts = m.size == 4 ? m[3] : m[2]
        opts.split(",").map(&:strip).include?("noatime")
      end
    end

    # newline_conv.c: open through rb_file_open / rb_io_fdopen with a mode of
    # "r" or "w" and "b" or "t". Through the C API a "t" converts nothing on
    # a Unix (no universal-newline decorator is set up there), where Ruby's own
    # File.open "rt" would turn CRLF into LF -- so the "t" is not passed on.
    module NewlineConv
      def self.__mode(read_or_write, binary_or_text)
        m = case read_or_write
            when :read then +"r"
            when :write then +"w"
            else raise ArgumentError, "read_or_write param must be :read or :write"
            end
        case binary_or_text
        when :binary then m << "b"
        when :text then m
        else raise ArgumentError, "binary_or_text param must be :binary or :text"
        end
        m
      end
      def self.rb_file_open(filename, read_or_write, binary_or_text)
        ::File.open(filename, __mode(read_or_write, binary_or_text))
      end
      def self.rb_io_fdopen(filename, read_or_write, binary_or_text)
        mode = __mode(read_or_write, binary_or_text)
        flags = read_or_write == :read ? ::File::RDONLY : (::File::WRONLY | ::File::CREAT | ::File::TRUNC)
        fd = IO.sysopen(filename, flags, 0o644)
        IO.new(fd, mode)
      end
    end

    # stat.c
    module Stat
      def self.for_fd(fd) = IO.for_fd(fd, autoclose: false).stat
      def self.for_path(path) = ::File.stat(path)
    end
  end
end
