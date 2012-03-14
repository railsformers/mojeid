# helper methods

def xrds_meta(request)
  "<meta http-equiv=\"x-xrds-location\" content=\"#{request.protocol}#{request.host_with_port}/xrds.xml\" />"
end

def xrds_response(return_url)
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<xrds:XRDS xmlns:xrds=\"xri://$xrds\" xmlns=\"xri://$xrd*($v*2.0)\">
   <XRD>
     <Service>
       <Type>http://specs.openid.net/auth/2.0/return_to</Type>
       <URI>#{return_url}</URI>
     </Service>
   </XRD>
</xrds:XRDS>"
end
