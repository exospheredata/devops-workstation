$env:PACKER_LOG=1
$env:PACKER_LOG_PATH="packerlog.txt"

packer build -var-file packer_variables/windows_2016.json `
 -on-error=cleanup `
 vsphere/eval-windows-2016-vmware.json
