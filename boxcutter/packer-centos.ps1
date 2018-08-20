$env:PACKER_LOG=1
$env:PACKER_LOG_PATH="packerlog.txt"

packer build -var-file packer_variables/centos_7.json `
 -on-error=cleanup `
 vsphere/centos-7.4-x86_64.json
