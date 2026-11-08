# Read identities for the first time only after hiding external commands.
previous_path = ENV["PATH"]
previous_status = $?
begin
  ENV["PATH"] = ENV.fetch("IDENTITY_TEST_PATH", "")
  ids = [Process.uid, Process.gid, Process.euid, Process.egid]
  p ids
  p ids.all? { |id| id.is_a?(Integer) && id >= 0 }
  p [Process::UID.rid, Process::GID.rid, Process::UID.eid, Process::GID.eid] == ids
  p [Process::Sys.getuid, Process::Sys.getgid, Process::Sys.geteuid, Process::Sys.getegid] == ids
  p 3.times.map { [Process.uid, Process.gid, Process.euid, Process.egid] }.all? { |values| values == ids }
  p $?.equal?(previous_status)
  p File.stat(__FILE__).owned?
  p File.stat(__FILE__).readable?
ensure
  ENV["PATH"] = previous_path
end
