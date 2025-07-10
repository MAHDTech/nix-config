# Nested Nutanix Community Edition ISO Builder

This script (`nested-nce.sh`) creates a modified version of the Nutanix Community Edition ISO that can run nested in another hypervisor.

## Prerequisites

### Required Software

- `mkisofs` - For creating ISO files
- `zcat` - For decompressing files
- `cpio` - For archive operations
- `gzip` - For compression
- `tar` - For archive operations
- `sudo` - For mounting ISO files

### Required Files

- Nutanix Community Edition ISO file named `phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga.iso` <!-- spellchecker:ignore-line -->
- Place the ISO file in the `iso/` directory relative to the script

## Usage

1. **Download the Nutanix Community Edition ISO** from the official website
2. **Place the ISO** in the `iso/` directory
3. **Run the script**:

```bash
./nested-nce.sh
```

## What the Script Does

1. **Mounts the original ISO** as read-only
2. **Extracts the ISO contents** to a temporary directory
3. **Unpacks the initrd** (initial ramdisk)
4. **Applies patches** to Python scripts to replace PCI device paths with LNXSYSTM paths
5. **Repacks the initrd** with the modified files
6. **Replaces the initrd** in the ISO contents
7. **Pauses for manual changes** - You can modify any files in the ISO contents
8. **Creates the final ISO** with all modifications
9. **Optionally tests** the ISO with QEMU (if available)

## Manual Changes

After the script patches the initrd, it will pause and show you the location of the ISO contents:

```bash
Location: /path/to/tmpdir/phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga.iso
```

You can make any additional modifications to files in this directory before pressing Enter to create the final ISO.

## Output

The modified ISO will be created as:

```bash
output/phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga-hv-mkiso.iso
```

## Troubleshooting

### Common Issues

1. **"No such file or directory" errors**: Make sure the ISO file exists in the `iso/` directory
2. **Permission errors**: Ensure you have sudo privileges and are not running as root
3. **Missing dependencies**: Install the required packages listed above
4. **Mount errors**: Ensure the ISO file is not corrupted and you have sufficient disk space

### Cleanup

The script automatically cleans up temporary files and unmounts the ISO when it exits (normally or due to errors).

## Notes

- The script modifies Python files in the initrd to replace `/sys/devices/pci` paths with `/sys/devices/LNXSYSTM` paths
- This modification allows the Nutanix installer to work in nested virtualization environments
- The original ISO file is never modified - only a copy is created
- The script requires sudo privileges for mounting ISO files
