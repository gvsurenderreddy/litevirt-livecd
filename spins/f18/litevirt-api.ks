%packages --excludedocs --nobase
lighttpd
lighttpd-fastcgi
python-webpy
python-flup
python-mimeparse
gamin
litevirt-api 
%end

%post
echo "Enable lighttpd service"
ln -s '/usr/lib/systemd/system/lighttpd.service' '/etc/systemd/system/multi-user.target.wants/lighttpd.service'

echo "Configure litevirt api service"
cat >> /etc/lighttpd/lighttpd.conf <<EOF
#%litevirt section
\$SERVER["socket"] == ":443" {
       ssl.engine   = "enable"
       ssl.pemfile  = "/etc/ssl/private/lighttpd.cert"
}
#%end litevirt
EOF

cat >> /etc/lighttpd/modules.conf <<EOF
#%litevirt section
include "conf.d/fastcgi.conf"
#%end litevirt
EOF

cat >> /etc/lighttpd/conf.d/fastcgi.conf <<EOF
#%litevirt section
server.modules += ( "mod_rewrite" )

fastcgi.server = ( "/server.py" =>
  ((
      "socket" => "/tmp/fastcgi.socket",
      "bin-path" => server_root + "/litevirt/server.py",
      "max-procs" => 1,
      "bin-environment" => (
          "REAL_SCRIPT_NAME" => ""
     ),
      "check-local" => "disable"
   ))
)

url.rewrite-once = (
        "^/favicon.ico$" => "/static/favicon.ico",
        "^/static/(.*)$" => "/static/$1",
        "^/api/(.*)$" => "/server.py/$1",
       )
#%end litevirt
EOF

%end

%post --interpreter=image-minimizer --nochroot
drop /usr/lib64/libgamin*
drop /usr/libexec/gam_server
%end
