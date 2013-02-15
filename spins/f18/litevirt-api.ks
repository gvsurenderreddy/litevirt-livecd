%packages --excludedocs --nobase
lighttpd
lighttpd-fastcgi
python-webpy
python-flup
python-mimeparse
gamin 
%end

%post
echo "Enable lighttpd service"
ln -s '/usr/lib/systemd/system/lighttpd.service' '/etc/systemd/system/multi-user.target.wants/lighttpd.service'

echo "Configure litevirt api service"
socket_dir=/var/cache/lighttpd/sockets
mkdir -p $socket_dir
chmod 777 $socket_dir


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
      "socket" => socket_dir + "/fastcgi.socket",
      "bin-path" => server_root + "/litevirt/server.py",
      "max-procs" => 5,
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
