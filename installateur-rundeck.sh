#! /bin/bash
#Author...: Eric Gigondan (Itsatsu)
#Date.....: 16/07/2019
#Version..: 1.69.3.23
#comment..: Installer for debian 9 !
#Script that allows the installation of the Rundeck master server 
echo "Installation de net-tools"
apt-get install -y net-tools

echo "Verification de la disponibilité des ports 4440 et 4443"
netstat -an | egrep "4440|4443" >> /tmp/tmp.port
if grep -q 4440 /tmp/tmp.port;
	then
	echo -e "\033[30;41m Le port 4440 n'est pas diponible, l'installation à échoué! \033[0m "
	rm /tmp/tmp.port
	exit
fi

if grep -q 4443 /tmp/tmp.port;
	then
	echo -e "\033[30;41m Le port 4443 n'est pas diponible, l'installation à échoué! \033[0m "
	rm /tmp/tmp.port
	exit
fi
rm /tmp/tmp.port

echo "Installation de openjdk 8"
apt-get install -y openjdk-8-jdk-headless
echo "installation d' expect"
apt-get install -y expect
echo " "
echo "Téléchargement du packet rundeck"
mkdir /deck
dlink="https://dl.bintray.com/rundeck/rundeck-deb/rundeck_3.0.23.20190619-1.201906191858_all.deb"
wget -P /deck ${dlink}

echo "Installation de uuid"
apt-get install -y uuid-runtime
grep -lr -e "rundeck.*" /deck/ >> /tmp/versionrun.txt
rundeck="$(</tmp/versionrun.txt)"

echo "Installation du packet Rundeck"
dpkg -i ${rundeck}

rm /tmp/versionrun.txt

echo "Installation de mysql serveur"
apt-get install -y mysql-server
echo " "
echo " "

echo "Création de la base de donnée rundeck et de l'utilisateur rundeck"
echo -e "\033[30;41m Enter le mot de passe de l'utilisateur rundeck qui va etre crée dans mysql \033[0m "
echo -e "\033[30;41m ( minimum 1 majuscule, 1 minuscule, 1 chiffre) \033[0m "
read pswdmysql
echo -e "\033[30;41m Entrer le mot de passe root \033[0m "
mysql -u root -p -e "CREATE database rundeck; CREATE USER 'rundeck'@'localhost' IDENTIFIED BY '"${pswdmysql}"'; GRANT ALL PRIVILEGES ON rundeck.* TO 'rundeck'@'localhost'; FLUSH PRIVILEGES;"

service rundeckd start
echo "Le serveur se construit"
echo  -e "\033[30;41m cette operation prend 5 minutes, le script est toujours en cours \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 4 minutes \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 3 minute \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 2 minute \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 1 minute \033[0m "
sleep 1m

service rundeckd stop

echo "Création de scripts suplémentaires"
mkdir /etc/scriptrundeck

chown rundeck:rundeck /etc/scriptrundeck
chmod 755 /etc/scriptrundeck

echo '
#!/usr/bin/expect

#Author...: Eric Gigondan (Itsatsu)
#Date.....: 28/06/2019
#Version..: 1.4
#comment..: For Rundeck Debian server
# Ssh key exchange script

set ip [lindex $argv 0]
set port [lindex $argv 1]
set password [lindex $argv 2]
set project_name [lindex $argv 3]
set node_name [lindex $argv 4]
set node_description [exec cat /tmp/description${node_name}]
set node_tags [lindex $argv 5]
set node_os [lindex $argv 6]
set node_user [lindex $argv 7]

spawn sed -i "5i <node name=\"${node_name}\" description=\"${node_description}\" tags=\"${node_tags}\" hostname=\"${ip}:${port}\" osFamily=\"unix\" osName=\"${node_os}\" username=\"${node_user}\"/>" /var/rundeck/projects/${project_name}/etc/resource.xml

spawn ssh-copy-id -p ${port} -i /var/rundeck/projects/${project_name}/etc/id-rsa root@${ip}
sleep 2
expect {
        "(yes/no)? " {

        send "yes\r"

        expect "password:"
        sleep 4
        send "${password}\r"

        }

        "password:" {
        sleep 4
        send "${password}\r"

        }
        }
sleep 4
interact "\r"
' >> /etc/scriptrundeck/key_exchange

chown rundeck:rundeck /etc/scriptrundeck/key_exchange
chmod 755 /etc/scriptrundeck/key_exchange


echo '
#!/usr/bin/expect

#Author...: Eric Gigondan (Itsatsu)
#Date.....: 02/07/2019
#Version..: 1.4
#comment..: For Rundeck Debian server
# Ssh key creation script

set project_name [lindex $argv 0]

spawn ssh-keygen
expect "id_rsa:)"
send "/var/rundeck/projects/${project_name}/etc/id-rsa\r"
expect {
    "Overwrite (y/n)? " {
      send "y\r"
      sleep 2
      expect "no passphrase):"
      send "\r"
      expect "passphrase again:"
      send "\r"
    }
    "no passphrase):" {
      send "\r"
      expect "passphrase again:"
      send "\r"
    }
}
sleep 2
spawn chown rundeck:rundeck /var/rundeck/projects/${project_name}/etc/id-rsa.pub
spawn chown rundeck:rundeck /var/rundeck/projects/${project_name}/etc/id-rsa
sleep 4
interact "\r"
' >> /etc/scriptrundeck/create_a_key

chown rundeck:rundeck /etc/scriptrundeck/create_a_key
chmod 755 /etc/scriptrundeck/create_a_key

echo '
#!/usr/bin/expect

#Author...: Eric Gigondan (Itsatsu)
#Date.....: 28/06/2019
#Version..: 1.4
#comment..: For Rundeck Debian server
# Script to revoke an ssh key

set ip_node [lindex $argv 0]
set port [lindex $argv 1]
set password [lindex $argv 2]
set project_name [lindex $argv 3]
set node_name [lindex $argv 4]
set key_value [exec cut -c1-80 /var/rundeck/projects/${project_name}/etc/id-rsa.pub]

spawn sed -i "/.*name=\"${node_name}\".*/d" /var/rundeck/projects/${project_name}/etc/resource.xml
spawn ssh -p ${port} root@${ip_node} sed -i \"/${key_value}/d\" /root/.ssh/authorized_keys
sleep 5
expect "password: "
send "${password}\r"
interact "\r"

sleep 5 ' >> /etc/scriptrundeck/revoke_a_key

chown rundeck:rundeck /etc/scriptrundeck/revoke_a_key
chmod 755 /etc/scriptrundeck/revoke_a_key

update-rc.d -f rundeckd defaults

adduser rundeck root

echo -e "\033[30;41m Création des certificats ssl \033[0m "
cd /etc/rundeck/ssl
echo -e "\033[30;41m Crée le mot de passe de la clé \033[0m "
read pswdkey
echo -e "\033[30;41m Crée le mot de passe du coffre à clé \033[0m "
read pswdstore
echo -e "\033[30;41m Entrer l'adresse ip de ce serveur \033[0m "
read ipsrv
echo -e "\033[30;41m Entrer le nom de votre service \033[0m "
read nameservice
echo -e "\033[30;41m Entrer le nom de votre entreprise \033[0m "
read nameorg
echo -e "\033[30;41m Entrer le nom de votre ville \033[0m "
read namecity
echo -e "\033[30;41m Entrer le nom de votre région \033[0m "
read namestate
keytool -keystore /etc/rundeck/ssl/keystore -alias rundeck -genkey -keyalg RSA -keypass ${pswdkey} -storepass ${pswdstore} <<!
${ipsrv}
${nameservice}
${nameorg}
${namecity}
${namestate}
FR
oui
!

echo "Configuration du coffre ssl "
cp keystore truststore
sed -i "s/keystore.password=adminadmin/keystore.password=${pswdstore}/" ssl.properties
sed -i "s/key.password=adminadmin/key.password=${pswdkey}/" ssl.properties
sed -i "s/truststore.password=adminadmin/truststore.password=${pswdstore}/" ssl.properties
cd

echo "Ajout du ssl dans les fichier de configuration de rundeck"
cd /etc/rundeck
sed -i 's/:4440/:4443/' framework.properties
sed -i 's/http/https/' framework.properties
echo 'framework.rundeck.url=https://localhost:4443' >>framework.properties
sed -i "s/localhost:4440/${ipsrv}:4443/" rundeck-config.properties
sed -i 's/http/https/' rundeck-config.properties
sed -i '/dataSource.url = jdbc/d' rundeck-config.properties
sed -i "10i dataSource.url = jdbc:mysql://localhost/rundeck?autoReconnect=true" rundeck-config.properties
sed -i "11i dataSource.driverClassName=com.mysql.jdbc.Driver" rundeck-config.properties
sed -i "11i dataSource.password = ${pswdmysql}" rundeck-config.properties
sed -i "11i dataSource.username = rundeck" rundeck-config.properties
cd
cd /etc/default
echo "export RUNDECK_WITH_SSL=true" > rundeckd
echo "export RDECK_HTTPS_PORT=4443" >> rundeckd

echo -e "\033[30;41m Voulez vous ajouter la connexion de Rundeck à un serveur smtp ( oui ou non ) \033[0m "
read repsmtp
if [ "${repsmtp}" == "oui" ]
	then
	echo -e "\033[30;41m Entrer l'adresse email qui sera utilisé par rundeck \033[0m "
	read rundeck_mail
	echo -e "\033[30;41m Entrer le mot de passe de l'adresse email utilisé par rundeck \033[0m "
	read rundeck_mail_password
	echo -e "\033[30;41m Entrer l'adresse du serveur smtp sans le port \033[0m "
	read rundeck_smtp
	echo -e "\033[30;41m Entrer le port du serveur smtp \033[0m "
	read rundeck_smtp_port


	echo "
grails.mail.default.from= ${rundeck_mail}
grails.mail.host=${rundeck_smtp}
grails.mail.port=${rundeck_smtp_port}
grails.mail.username=${rundeck_mail}
grails.mail.password=${rundeck_mail_password}">> /etc/rundeck/rundeck-config.properties
fi

echo -e "\033[30;41m Voulez vous ajouter la connexion de Rundeck à un serveur LDAP ( oui ou non ) \033[0m "
read repldap
if [ "${repldap}" == "oui" ]
then
	echo -e "\033[30;41m Entrer le providerUrl du ldap \033[0m "
	read providerldap
	echo -e "\033[30;41m Enter le bindDn (ex: CN=utilisateur,CN=Users,DC=Entreprise,...) \033[0m "
	read binddn
	echo -e "\033[30;41m Enter le mot de passe du bind \033[0m "
	read bindpassword
	echo -e "\033[30;41m Enter les roles de la base dn (ex: dc=Entreprise,dc=Sitedistant ) \033[0m "
	read rolebasedn
	echo -e "\033[30;41m Enter l' OU(Organizational Unit) du ldap qui sera accepté à utiliser rundeck \033[0m "
	read ldapgroup
	echo "
activedirectory {
	com.dtolabs.rundeck.jetty.jaas.JettyCachingLdapLoginModule required
	debug=\"true\"
	contextFactory=\"com.sun.jndi.ldap.LdapCtxFactory\"
	providerUrl=\"${providerldap}\"
	bindDn=\"${binddn}\"
	bindPassword=\"${bindpassword}\"
	authenticationMethod=\"simple\"
	forceBindingLogin=\"true\"
	userBaseDn=\"${rolebasedn}\"
	userRdnAttribute=\"sAMAccountName\"
	userIdAttribute=\"sAMAccountName\"
	userPasswordAttribute=\"unicodePdw\"
	userObjectClass=\"user\"
	roleBaseDn=\"${rolebasedn}\"
	roleNameAttribute=\"cn\"
	roleMemberAttribute=\"member\"
	roleObjectClass=\"group\"
	cacheDurationMillis=\"300000\"
	reportStatistics=\"true\";
};
	" > /etc/rundeck/jaas-activedirectory.conf

	chown rundeck:rundeck /etc/rundeck/jaas-activedirectory.conf
	chmod 755 /etc/rundeck/jaas-activedirectory.conf

	echo "RDECK_JVM_OPTS= \"-Drundeck.jaaslogin=true \
       -Djava.security.auth.login.config=/etc/rundeck/jaas-activedirectory.conf \
       -Dloginmodule.name=activedirectory \"" >> /etc/default/rundeckd

	sed -i "s/admin/${ldapgroup}/" /etc/rundeck/admin.aclpolicy

fi
service rundeckd start
mkdir /etc/rundeck/coffreacle
mkdir /var/rundeck/resource
mkdir /var/rundeck/resource/xml
mkdir /var/rundeck/resource/cle
chown rundeck:rundeck /etc/rundeck/coffreacle
chown rundeck:rundeck /var/rundeck/resource
chown rundeck:rundeck /var/rundeck/resource/xml
chown rundeck:rundeck /var/rundeck/resource/cle
chmod 755 /etc/rundeck/coffreacle

rm ${rundeck}
rmdir /deck

echo -e "\033[30;41m Le serveur est en cours de démarrage \033[0m "
echo -e "\033[30;41m L'interface web sera disponible dans 5 minutes à l'adresse suivante: \033[0m "
echo -e "\033[30;41m https://${ipsrv}:4443 \033[0m "
if [ "${repldap}" == "non" ]
then
echo -e "\033[30;41m Pseudo: admin 
Mot de passe : admin \033[0m " 
fi
cd
