#!/bin/bash
echo "N'oubliez pas de supprimer ce fichier après avoir sauvegarder les informations." > config.txt

# Suppression des images Docker sur le poste
read -p "Souhaitez-vous une suppression de toutes vos images Docker ? (y/N) " deleteimages
if [[ $deleteimages == 'Y' || $deleteimages == 'y' ]]; then
	echo "passe"

	docker stop $(docker ps -a -q)
	docker rm $(docker ps -a -q)
	docker rmi $(docker images -q)
fi

echo " "
echo "############################################################"
echo " "
read -p "Souhaitez-vous une configuration automatique ? (Y/n) " configauto

echo " " >> config.txt

apt install pwgen -y -qq
# Vérification de la réponse
if [[ $configauto == 'N' || $configauto == 'n' ]]; then
	# Configuration du nom de l'image MySQL
	containername=$(pwgen -1 -0 8)
	read -p "Nom du container MySQL ? [${containername}] " containermysql
	if [[ $containermysql == '' ]]; then
		containermysql=${containername}
	fi

	# Configuration du mot de passe mysql root
	read -p "Mot de passe Root pour MySQL ? [RANDOM] " msqlrpass
	if [[ $msqlrpass == '' ]]; then
		msqlrpass=$(pwgen -c -B -sy 16 1)
	fi

	# Création d'un nouvel utilisateur
	read -p "Souhaitez-vous créer un nouvel utilisateur MySQL ? (Y/n) " asknewuser
	if [[ $asknewuser == 'Y' || $asknewuser == 'y' || $asknewuser == '' ]]; then
		# Nom de l'utilisateur
		read -p "Entrez le nom de l'utilisateur à créer [RANDOM] " mysqlusername
		if [[ $mysqlusername == '' ]]; then
			mysqlusername=$(pwgen -1 -0 10)
		fi

		# Password
		read -p "Entrez un mot de passe à créer [RANDOM] " mysqluserpassword 
		if [[ $mysqluserpassword == '' ]]; then
			mysqluserpassword=$(pwgen -c -B -sy 16 1)
		fi

		requser="-e MYSQL_USER=${mysqlusername} -e MYSQL_PASSWORD=${mysqluserpassword}"
	else
		requser=""
	fi

	# Création d'une nouvelle base de donnée
	read -p "Souhaitez-vous créer une base de donnée ? (Y/n)" asknewdb
	if [[ $asknewdb == 'Y' || $asknewdb == 'y' || $asknewdb == '' ]]; then
		read -p "Entrez le nom de la base de donnée à créer [RANDOM] " mysqldbname
		if [[ $mysqldbname == '' ]]; then
			mysqldbname=$(pwgen -1 -0 10)
		fi

		reqmysqldb="-e MYSQL_DATABASE=${mysqldbname}"
	fi

	# Configuration PMA
	containername=$(pwgen -1 -0 8)
	read -p "Nom du container PhpMyAdmin ? [${containername}] " containerpma
	if [[ $containerpma == '' ]]; then
		containerpma=${containername}
	fi

	# Configuration Apache
	containername=$(pwgen -1 -0 8)
	read -p "Nom du container Apache ? [${containername}] " containerapache
	if [[ $containerapache == '' ]]; then
		containerapache=${containername}
	fi

	# Configuration Rancher
	containername=$(pwgen -1 -0 8)
	read -p "Nom du container Rancher ? [${containername}] " containerrancher
	if [[ $containerrancher == '' ]]; then
		containerrancher=${containername}
	fi

else
	# Configuration MySQL
	containermysql=$(pwgen -1 -0 8)
	msqlrpass=$(pwgen -c -B -sy 16 1)
	mysqlusername=$(pwgen -1 -0 10)
	mysqluserpassword=$(pwgen -c -B -sy 16 1)
		requser="-e MYSQL_USER=${mysqlusername} -e MYSQL_PASSWORD=${mysqluserpassword}"
	mysqldbname=$(pwgen -1 -0 10)
		reqmysqldb="-e MYSQL_DATABASE=${mysqldbname}"

	# Configuration PMA
	containerpma=$(pwgen -1 -0 8)

	# Configuration Apache
	containerapache=$(pwgen -1 -0 8)

	# Configuration Rancher
	containerrancher=$(pwgen -1 -0 8)
fi

# Ecriture de configuration
	echo "Nom du container MySQL : ${containermysql}" >> config.txt
	echo "MySQL Root Password : ${msqlrpass}" >> config.txt
	echo "MySQL User : ${mysqlusername}" >> config.txt
	echo "MySQL Password : ${mysqluserpassword}" >> config.txt
	echo "Base de donnée MySQL : ${mysqldbname}" >> config.txt
	echo "" >> config.txt
	echo "Nom du container PMA : ${containerpma}" >> config.txt
	echo "" >> config.txt
	echo "Nom du container Apache : ${containerapache}" >> config.txt
	echo "" >> config.txt
	echo "Nom du container Rancher : ${containerrancher}" >> config.txt

# Lancement des containers
	# MySQL
	docker run --name ${containermysql} -e MYSQL_ROOT_PASSWORD=${msqlrpass} ${requser} ${reqmysqldb} -d mysql
	containermysqlid=$(docker ps -aqf "name=${containermysql}")

	# PhpMyAdmin
	docker run --name ${containerpma} --link ${containermysqlid} -p 4000:80 -d phpmyadmin/phpmyadmin
	containerpmaid=$(docker ps -aqf "name=${containerpma}")

	# Configuration Apache
	docker build -f apache.dockerfile -t apache .
	docker run --name ${containerapache} --link ${containermysqlid} -p 5000:80 -d apache
	containerapacheid=$(docker ps -aqf "name=${containerapache}")

	# Configuration Rancher
	docker run --name ${containerrancher} -d --restart=always --link ${containermysqlid} --link ${containerpmaid} --link ${containerapacheid} -p 444:8080 rancher/server
	containerrancherid=$(docker ps -aqf "name=${containerrancher}")

	echo "URL Apache : http://172.17.0.1:5000" >> config.txt
	echo "URL PMA : http://172.17.0.1:4000" >> config.txt
	echo "URL Rancher : http://172.17.0.1:444" >> config.txt

	# sudo docker run -e CATTLE_AGENT_IP="57887561340f"  --rm --privileged  -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.2 http://127.17.0.1:444/v1/scripts/A5B52C0C726E42DA2AE9:1483142400000:hm6anu52dnbB7u7QMSXptrXRxOI
