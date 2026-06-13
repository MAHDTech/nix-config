{
  # Linux Security Modules (LSM)
  #
  # - landlock: Unprivileged sandboxing — lets processes restrict their own file/network access
  # - yama: Ptrace hardening — restricts which processes can debug/trace others
  # - bpf: eBPF-based security hooks — enables BPF programs to enforce security policies
  security = {
    lsm = [
      "landlock"
      "yama"
      "bpf"
    ];
  };
}
