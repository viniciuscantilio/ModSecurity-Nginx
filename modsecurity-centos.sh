### 
# ModSecurity NGINX INSTALLATION SCRIPT
##

echo ## Atualizando ##
yum groupinstall 'Development Tools' -y

yum install -y gcc-c++ flex bison yajl yajl-devel curl-devel curl GeoIP-devel doxygen zlib-devel 

yum install -y lmdb lmdb-devel libxml2 libxml2-devel ssdeep ssdeep-devel lua lua-devel pcre-devel

cat > /etc/yum.repos.d/nginx.repo <<EOL
[nginx]
name=nginx repo
baseurl=https://nginx.org/packages/mainline/centos/7/x86_64/
gpgcheck=0
enabled=1
EOL

yum install -y nginx 

echo "Welcome To ModSecurity NGINX Installation........"

echo "Enter into $OPT_DIR"
cd $OPT_DIR

# ----------------------- STEP-1: libModSecurity Installation -----------------------
echo "Cloning libModSecurity git repositry..."
git clone https://github.com/SpiderLabs/ModSecurity
echo "Cloning done..."

echo "Enter into cloned repository directory, checkout to v3/master branch..."
cd ModSecurity
git checkout v3/master

echo "Pulling couple of necessarysub-modules..."
git submodule init
git submodule update
echo "\n submodule update done, we are ready to build libModSecurity..."

echo "Compiling and installing library..."
sh build.sh
./configure
make
make install


OPT_DIR=/opt
NGINX_DIR=/usr/local/se/apps/nginx
MODSEC_DIR=/usr/local/se/apps/nginx/modsec
MODULES_DIR=/usr/local/se/apps/nginx/modules

NGINX_VERSION=$(nginx -v 2>&1)
NGINX_VER_NO=${NGINX_VERSION//[^0-9.]/}

echo "Installed Nginx Version: $NGINX_VERSION"

echo "\n Entering into $OPT_DIR..."
cd $OPT_DIR

echo "Downloading source code for Nginx Version: $NGINX_VER_NO"
wget http://nginx.org/download/nginx-1.19.0.tar.gz
echo "Download completed, unpacking archive..."
tar -xvf nginx-1.19.0.tar.gz
echo "Unpacking done..."

echo "\n Entering into $OPT_DIR..."
cd $OPT_DIR

echo "Cloning ModeSecurity-nginx git repository into $OPT_DIR..."
git clone https://github.com/SpiderLabs/ModSecurity-nginx
echo "Cloning of ModeSecurity-nginx git repo done..."

echo "Entering into nginx directory that we cloned and unpacked earlier..."
cd $OPT_DIR/nginx-$NGINX_VER_NO

echo "Compiling connector ...."
./configure --with-compat --add-dynamic-module=/opt/ModSecurity-nginx
make modules

echo "Compiling done, copying connector module into the nginx modules directory..."
mkdir $MODULES_DIR
cp objs/ngx_http_modsecurity_module.so /usr/local/se/apps/nginx/modules/
cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules
echo "Compiling and copying of connector done, now lets configure nginx to use it..."

echo "Enter into nginx directory: $NGINX_DIR"
OPT_DIR=/opt
NGINX_DIR=/usr/local/se/apps/nginx
MODSEC_DIR=/usr/local/se/apps/nginx/modsec
MODULES_DIR=/usr/local/se/apps/nginx/modules
cd $NGINX_DIR
mkdir $MODSEC_DIR
cd $MODSEC_DIR

echo "Loading ModSecurity rules and configuration into $MODSEC_DIR ..."
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs

echo "Renaming ModSecurity rules configuration file to use it..."
mv $MODSEC_DIR/owasp-modsecurity-crs/crs-setup.conf.example $MODSEC_DIR/owasp-modsecurity-crs/crs-setup.conf

echo "Copying ModSecurity configuration file from the directory where we built libModSecurity to usr/local/se/apps/nginx/modsec/"
cp /opt/ModSecurity/modsecurity.conf-recommended $MODSEC_DIR/modsecurity.conf
cp -a /opt/ModSecurity/unicode.mapping $MODSEC_DIR

echo "Creating a new configuration file that loads these two configuration files and all the rules files"

cat > $MODSEC_DIR/main.conf <<EOL
Include usr/local/se/apps/nginx/modsec/modsecurity.conf
Include usr/local/se/apps/nginx/modsec/owasp-modsecurity-crs/crs-setup.conf
Include usr/local/se/apps/nginx/modsec/owasp-modsecurity-crs/rules/*.conf
EOL

echo "Replacing 'SecRuleEngine DetectionOnly' to 'SecRuleEngine On'"
sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/g' /usr/local/se/apps/nginx/modsec/modsecurity.conf

# REMOVING DIRECTORIES CLONED IN /opt
echo "Removing cloned directories from $OPT_DIR"
rm -rf $OPT_DIR/ModSecurity  $OPT_DIR/ModSecurity-nginx  $OPT_DIR/nginx-$NGINX_VER_NO  $OPT_DIR/nginx-$NGINX_VER_NO.tar.gz
echo "Removed: \n1) $OPT_DIR/ModSecurity  \n2)$OPT_DIR/ModSecurity-nginx  \n3)$OPT_DIR/nginx-$NGINX_VER_NO  \n4)$OPT_DIR/nginx-$NGINX_VER_NO.tar.gz"
