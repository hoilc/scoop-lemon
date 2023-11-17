# https://github.com/ScoopInstaller/Extras/blob/master/scripts/zotero/uninstall-zotero-url-protocol.ps1
Write-Host 'Unregistering the ''zotero://'' URL protocol...'
Remove-Item 'HKCU:\SOFTWARE\Classes\zotero' -Recurse -Force
Write-Host 'Done!'
