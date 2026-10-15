# Time holds an exact instant: what is under the nanosecond (a Rational, or a
# Float's binary fraction) and years that int64 seconds cannot hold, folded
# into 400-year cycles (note 356). Before, the subsec was cut to nanoseconds,
# a second count past ±292 years overflowed, and a Bignum year was 1970.
ENV["TZ"] = "UTC"
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{label}: #{r.inspect}"
end
t("u4000") { x = Time.utc(-4000,1,1); [x.year, x.mon, x.day, x.wday, x.to_i] }
t("u-4.5e9") { x = Time.utc(-4.5e9,1,1); [x.year, x.to_i, x.inspect] }
t("u5.67e9") { x = Time.utc(5.67e9,4,8); [x.year, x.to_i, x.inspect] }
t("m-4.5e9") { x = Time.utc(-4.5e9,1,1); Marshal.load(Marshal.dump(x)).inspect }
t("m30000") { x = Time.utc(30000,1,1); Marshal.load(Marshal.dump(x)).inspect }
t("u2**100") { x = Time.utc(1<<100,1,1); [x.year, x.mon, x.day, x.to_i] }
t("at2**40") { x = Time.at(2**40 + "1/3".to_r, 9999999999999).utc; [x.year, x.subsec] }
t("at-0x3f") { Time.at(-0x3fff_ffff_ffff_ffff).year }
t("at4611686018") { x = Time.at(4611686018, 999999).utc; [x.year, x.subsec] }
t("at10**30") { Time.at(10**30).utc.year }
t("strf_s") { Time.at(10**25).strftime("%s") }
t("insp") { Time.utc(2000,1,1,0,0,Rational(1,10000000000)).inspect }
t("insp2") { Time.utc(2000,1,1,0,0,Rational(1,3)).inspect }
t("plus") { (Time.utc(2000)+Rational(1,3)).subsec }
t("plus2") { (Time.at(0)+Rational(1,3)+Rational(2,3)).subsec }
t("minus") { (Time.utc(2000)+Rational(1,3)) - Time.utc(2000) }
t("xml") { Time.at(Rational(2,3)).utc.xmlschema(10) }
t("nfs") { Time.new("2000-01-01 00:00:00.123456789123 UTC").subsec }
t("strf_N") { Time.utc(1592,3,14,6,53,58+Rational("0.97932384626433832795028841971")).strftime("%L %N %30N") }
t("to_r") { Time.at(Rational(1,3)).to_r }
t("cmp") { Time.at(Rational(1,3)) <=> Time.at(Rational(1,3)+Rational(1,10**12)) }
t("eq") { Time.at(Rational(1,3)) == Time.at(Rational(1,3)) }
t("round") { Time.at(Rational(1,3)).round(12).subsec }
t("nsec") { Time.at(Rational(1,3)).nsec }
t("usec") { Time.at(Rational(1,3)).usec }
t("to_f") { Time.at(Rational(1,3)).to_f }
t("float") { Time.at(1.1).subsec }
a = Time.at(Rational(1,3))
t("dup") { [a.dup.subsec, a.clone.subsec, a.dup == a, a.dup.eql?(a), a.dup.hash == a.hash] }
t("at_t") { Time.at(a).subsec }
t("getutc") { [a.getutc.subsec, a.getlocal("+09:00").subsec, a.getlocal("+09:00").inspect] }
t("round") { [a.round(3).subsec, a.floor(10).subsec, a.ceil(10).subsec, a.ceil(0).to_i, a.round.to_i] }
t("plusf") { [(Time.at(0) + 0.1).subsec, (Time.at(0) + 0.1).nsec, (Time.at(100) + -1.3).usec] }
t("minus_t") { [(Time.at(Rational(1,3)) - Time.at(0)), Time.at(5) - Time.at(Rational(1,3))] }
t("nan") { Time.at(Float::NAN) }
t("inf") { Time.at(Float::INFINITY) }
t("ninf") { Time.at(0) + Float::INFINITY }
t("at_neg") { x = Time.at(-1.5); [x.to_i, x.nsec, x.subsec] }
t("far_cmp") { [Time.utc(1<<70) <=> Time.utc(1<<71), Time.utc(1<<70) == Time.utc(1<<70), Time.utc(-(1<<70)) < Time.utc(1970)] }
t("far_sort") { [Time.utc(1<<70), Time.utc(2000), Time.utc(-(1<<70))].sort.map(&:year) }
t("far_plus") { (Time.utc(1<<70) + 86400).day }
t("far_minus") { Time.utc((1<<70)+1) - Time.utc(1<<70) }
t("far_to_a") { Time.utc(1<<70, 5, 6, 7, 8, 9).to_a }
t("far_wday") { [Time.utc(1<<70, 5, 6).wday, Time.utc(1<<70, 5, 6).yday] }
t("far_strf") { Time.utc(1<<70, 5, 6).strftime("%Y %C %y %F %s %j %a") }
t("far_ctime") { Time.utc(1<<70, 5, 6).ctime }
t("far_iso") { Time.utc(1<<70, 5, 6).iso8601 }
t("far_hash") { h = {Time.utc(1<<70) => 1}; h[Time.utc(1<<70)] }
t("far_marshal") { x = Time.utc(1<<70, 5, 6, 7, 8, 9); Marshal.load(Marshal.dump(x)) == x }
t("far_local") { x = Time.local(1<<70, 5, 6); [x.year, x.hour, x.utc_offset] }
t("far_past_local") { x = Time.local(-(1<<70), 5, 6); [x.year, x.hour, x.utc_offset, x.zone] }
t("at_big") { x = Time.at(10**30); [x.to_i, x.year, x.utc.mon] }
t("at_big_sub") { x = Time.at(10**20, 5, :nsec); [x.to_i, x.nsec] }
t("marsh_rat") { x = Time.at(Rational(1,3)); y = Marshal.load(Marshal.dump(x)); [y == x, y.subsec] }
t("marsh_flt") { x = Time.at(1.1); y = Marshal.load(Marshal.dump(x)); [y == x, y.subsec] }
t("usecf") { Time.utc(2000,1,1,0,0,0, 0.5).subsec }
t("usecr") { Time.utc(2000,1,1,0,0,0, Rational(1,3)).subsec }
t("new_in") { x = Time.new(2000,1,1,0,0,Rational(1,3), in: "+09:00"); [x.subsec, x.inspect] }
t("strfN") { Time.at(Rational(1,3)).strftime("%N %3N %12N %L") }
t("iso") { Time.at(Rational(1,3)).utc.iso8601(12) }
t("to_f") { [Time.at(Rational(1,3)).to_f, Time.at(1.1).to_f, Time.utc(1<<70).to_f] }
t("cmp_mixed") { [Time.at(Rational(1,3)) > Time.at(0, 333333333, :nsec), Time.at(0,333333333,:nsec) == Time.at(Rational(333333333, 10**9))] }
t("hash_mixed") { Time.at(0,333333333,:nsec).hash == Time.at(Rational(333333333, 10**9)).hash }
t("range") { (Time.at(0)..Time.at(Rational(1,3))).cover?(Time.at(Rational(1,4))) }
t("sub_cls") { c = Class.new(Time); x = c.at(Rational(1,3)); [x.class == c, x.subsec] }
t("frozen") { Time.at(Rational(1,3)).freeze.subsec }
t("ivars") { Time.at(Rational(1,3)).instance_variables }
t("year2") { [Time.utc(9999999999).year, Time.utc(10000000000).year, Time.utc(-10000000000).year] }
t("insp_float") { (Time.utc(2000) + 0.1).inspect }
t("hash_key") { [{Time.at(1)=>1}[Time.at(1)], {Time.at(Rational(1,3))=>1}[Time.at(Rational(1,3))], {Time.utc(1<<70)=>1}[Time.utc(1<<70)], [Time.at(1), Time.at(1)].uniq.size] }
