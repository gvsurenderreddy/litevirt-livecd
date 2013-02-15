%packages --excludedocs --nobase
lighttpd
lighttpd-fastcgi
python-webpy
python-flup
gamin 
%end

%post
echo "Enable lighttpd service"
ln -s '/usr/lib/systemd/system/lighttpd.service' '/etc/systemd/system/multi-user.target.wants/lighttpd.service'

echo "Configure litevirt webapp."
mkdir -p /var/www/litevirt
cat > /var/www/litevirt/server.py <<EOF
#!/usr/bin/env python
import web

urls = (
    '/(.*)', 'hello'
)

class hello:
    def GET(self, name):
        if not name:
            name = 'world'
        return 'Hello, ' + name + '!'

if __name__ == "__main__":
    app = web.application(urls, globals())
    app.run()

EOF

chmod -R 755 /var/www/litevirt

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
        "^/(.*)$" => "/server.py/$1",
       )
#%end litevirt
EOF

%end

%post --interpreter=image-minimizer --nochroot
drop /usr/lib64/libgamin*
drop /usr/libexec/gam_server
%end
