# Description

This resource downloads a remote file to the local machine.

## Parameters

* **DestinationPath**: Path where the remote file should be downloaded.
  Required.
* **Uri**: URI of the file which should be downloaded. It must be a HTTP, HTTPS
  or FILE resource. Required.
* **UserAgent**: User agent for the web request. Optional.
* **Headers**: Headers of the web request. Optional.
* **Credential**: Specifies credential of a user which has permissions to send
  the request. Optional.
* **MatchSource**: Determines whether the remote file should be re-downloaded
  if file in the DestinationPath was modified locally. The default value is
  true. Optional.
* **TimeoutSec**: Specifies how long the request can be pending before it times
  out. Optional.
* **Proxy**: Uses a proxy server for the request, rather than connecting
  directly to the Internet resource. Should be the URI of a network proxy
  server (e.g 'http://10.20.30.1'). Optional.
* **ProxyCredential**: Specifies a user account that has permission to use the
  proxy server that is specified by the Proxy parameter. Optional.
* **Ensure**: Says whether DestinationPath exists on the machine. It's a read
  only property.
* **ChecksumType**: Specifies the algorithm used to calculate the checksum of
  the file. Optional.
  { *None* | SHA1 | SHA256 | SHA384 | SHA512 | MACTripleDES | MD5 | RIPEMD160 }.
* **Checksum**: Specifies the expected checksum value of downloaded file. Optional.
