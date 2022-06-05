Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
sudo su
/opt/jdk-17/bin/java -jar /home/ec2-user/backend.jar --db_username=${db_username} --db_password=${db_password} --db_host=${db_endpoint} --db_port=5432 --db_name=${db_name} --spring.profiles.active=generate-content,generate-orders --spring.jpa.hibernate.ddl-auto=create-drop &
--//--