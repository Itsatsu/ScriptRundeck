#! /bin/bash
#Author...: Eric Gigondan (Itsatsu)
#Date.....: 17/04/2019
#Version..: 1.3
#comment..: Installateur pour debian !
#Script qui permet l'installation du serveur maitre Rundeck 
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
dlink="https://dl.bintray.com/rundeck/rundeck-deb/rundeck_3.0.20.20190408-1.201904081511_all.deb"
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
echo "Entrer le mot de passe root"
mysql -u root -p -e "CREATE database rundeck; CREATE USER 'rundeck'@'localhost' IDENTIFIED BY '"${pswdmysql}"'; GRANT ALL PRIVILEGES ON rundeck.* TO 'rundeck'@'localhost'; FLUSH PRIVILEGES;"

service rundeckd start
echo "Le serveur se construit"
echo  -e "\033[30;41m cette operation prend 5 minutes, le script est toujours en cours \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 4 minutes \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 3 minutes \033[0m "
sleep 1m
echo -e "\033[30;41m Le script reprend dans 2 minutes \033[0m "
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
set ip [lindex $argv 0]
set mdp [lindex $argv 1]
set nomprojet [lindex $argv 2]
spawn ssh-copy-id -i /var/rundeck/projects/$nomprojet/etc/id-rsa root@$ip 
sleep 2
expect {
	"(yes/no)? " {
	
	send "yes\r"

	expect "password:"	
	sleep 3
	send "$mdp\r"
	
	}
	
	"password:" {
	sleep 3
	send "$mdp\r"
	
	}
	}
sleep 4
interact "\r"
' >> /etc/scriptrundeck/echange_de_cle

chown rundeck:rundeck /etc/scriptrundeck/echange_de_cle
chmod 755 /etc/scriptrundeck/echange_de_cle


echo '
#!/usr/bin/expect 
set nomprojet [lindex $argv 0]
set mdpcle [lindex $argv 1]
spawn ssh-keygen 
expect "id_rsa): "
send "/var/rundeck/projects/$nomprojet/etc/id-rsa\r"
expect "no passphrase:"
send "$mdpcle\r"
expect "passphrase again:"
send "$mdpcle\r"
sleep 2
spawn chown rundeck:rundeck /var/rundeck/projects/$nomprojet/etc/id-rsa.pub
spawn chown rundeck:rundeck /var/rundeck/projects/$nomprojet/etc/id-rsa
sleep 4
interact "\r"
' >> /etc/scriptrundeck/cree_une_cle

chown rundeck:rundeck /etc/scriptrundeck/cree_une_cle
chmod 755 /etc/scriptrundeck/cree_une_cle

echo "
#!/usr/bin/expect

set ipnoeud [lindex $argv 0]
set mdp [lindex $argv 1]
set nomduprojet [lindex $argv 2]
set valeurcle [exec cut -c1-70 /var/rundeck/projects/${nomduprojet}/etc/id-rsa.pub]

spawn ssh root@$ipnoeud sed -i \'/${valeurcle}/d\' /root/.ssh/authorized_keys

expect "password: "
send "${mdp}\r"
interact "\r"

sleep 4" >> /etc/scriptrundeck/revoquer_une_cle

chown rundeck:rundeck /etc/scriptrundeck/revoquer_une_cle
chmod 755 /etc/scriptrundeck/revoquer_une_cle

update-rc.d -f rundeckd defaults

adduser rundeck root

echo "Création des clefs ssl"
cd /etc/rundeck/ssl
echo "Crée le mot de passe de la clef"
read pswdkey
echo "Crée le mot de passe du coffre à clef"
read pswdstore
echo "Entrer l'adresse ip de ce serveur"
read ipsrv
echo "Entrer le nom de votre service"
read nameservice
echo "Entrer le nom de votre entreprise"
read nameorg
echo "Entrer le nom de votre ville"
read namecity
echo "Entrer le nom de votre région"
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

service rundeckd start

rm ${rundeck}
rmdir /deck

echo "Le serveur est en cours de démarrage"
echo "L'interface web sera disponible dans 5 minutes à l'adresse suivante: "
echo "https://${ipsrv}:4443"