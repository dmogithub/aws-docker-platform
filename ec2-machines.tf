resource "aws_key_pair" "deployer" {
  key_name   = "awspoc"
  public_key = "-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAm1sa7Dcjhh1CaPgCKzy4L2E1ekPXT2svW/u1PZaM/GyawknfkCJhBfJilQa8
cWK0u9Tz0mCd7J21rFsX8fvF0wXwpSjyqoGvjvM0UvaFyncMTnW2lMI6SP+1O+1KB87nJJNNNygr
+jEAUT5KiXi3LrrQyPgiEgubd7MFWyJUHgvb0ob8Uhfw4QPe7d7VSomMko29NA86mpeFUMwldnq4
S0v9n1+ac9/Ysjzj2URKrWx5fH7kalcFwdz1hX1DwN4c8sF5U30zQd0Umpl14kVLra+YvaSCpuTn
zAjYFShYOngjqj9Q5Fc9jLRQruwEHUbLcVJ1Ox5E0yaX5Rw4MX5M3QIDAQABAoIBADO6EOvHrCdS
hLMoqKg2zmjQKBsujXkfCiTJWV5JS2YczyaTrEF0gPOW8eYG2SWzpNPJoulQTCTlmgDqT729g++w
UaDcUngdOBQTvD9HX+K64rkZDpLXXMrDgVeTuYuCA4o1FYeg84uZVy612+GL9Qo1H6FapRV3Eeu4
Crd+ZZ2e8lBHy2Cghz7E3EvPipBh/qs9SABCsya/NVnnZ5LY01dH0DsIuE8JVzI/K2P+xC3tlXXh
XMVOCFP31AYmHjn9kwbGa+uYoRdXLihskznsNBb7KER23NgmrFn8AAQeLRGvh1jHAqfVgMsCGSSm
lLDb+Gp8TpVW/vL7hywxUvzSQ6ECgYEA/1WdNZUXzJ2bR8uXWvKPqO6kUufgWhqGNPxpIddl9sR2
D3mZIFsNdtdPz8xR9F8rCNIptUhvijHDwVm2ysT3S5ZQ4gl7d3MVShlKP9VTCoTW3lvg17Nne1bL
mtR1yeDIhquFuRgflpXCfKCF0vTojWbOVgFY63+srAiDVKYQWNUCgYEAm8LGX6tYY8+jQqsuAPSW
3z/1D+XHks6Snuh0+E8ZwGMxTat4v+d1W6Fjku2h79r1Rce2F9BAyiGAMpBivGrOCj6cvcru2VxM
VM3u3J/z4pZTNI+9Yzv/jA5G0vwKZtbVgbQGOFl3dEb0+H+LSLXDlByxItrdjFwX8nVQ8n1BJ+kC
gYEA/YbT121XuTrRASO9AHgSfwmdrhhA4xatJZVvCkQnITQHiewSSFdAcjzuKYVV5tBMGbEb6r2m
ytAI8EYVQxb5+Vqiqx4BMyTZAb9Ew0cc8jfeZeFSyrp/SK9w8SZ+YlpIobdTyuqSCuJev4Jf/oxh
EG4A+NLTqNoX6KV3SaiuWJUCgYBcbUrbsEhmCes9/2fwBzOTzFb2FQrFMbFNfHEUe5OzVukFxs+D
SKyaL/1vTXV/Z/WNb8G9BcW8a/6vgoAkgFg9OgQ2lzn+X0eoNv8bigrllQBQu07NmOe+SyZ5wjfF
6IuPSK08ONKqfASXhM+42Krys8fk/+zhgjBvnm/nRK4qKQKBgGeXie2JvMeRT+ybBCryCwDmFyT6
4shzbvtYb21WdoeNLvWalMiutctojaTD6olzAO23xwbrbl1FBVTJyUnhAlLtq+FIcDLBd7IfCZeN
2DmIr8GltYOVo7qGC/zIN1GFPx/DVN4gCaIU5daCbRn+sUycI8wVcF8CvDywrjm/CkH3
-----END RSA PRIVATE KEY-----"
}

resource "aws_instance" "phpapp" {
  ami           = "${lookup(var.AmiLinux, var.region)}"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id = "${aws_subnet.PublicAZA.id}"
  vpc_security_group_ids = ["${aws_security_group.FrontEnd.id}"]
  key_name = "awspoc"
  tags {
        Name = "phpapp"
  }
  user_data = <<HEREDOC
  #!/bin/bash
  yum update -y
  yum install -y httpd24 php56 php56-mysqlnd
  service httpd start
  chkconfig httpd on
  echo "<?php" >> /var/www/html/calldb.php
  echo "\$conn = new mysqli('mydatabase.linuxacademy.internal', 'root', 'secret', 'test');" >> /var/www/html/calldb.php
  echo "\$sql = 'SELECT * FROM mytable'; " >> /var/www/html/calldb.php
  echo "\$result = \$conn->query(\$sql); " >>  /var/www/html/calldb.php
  echo "while(\$row = \$result->fetch_assoc()) { echo 'the value is: ' . \$row['mycol'] ;} " >> /var/www/html/calldb.php
  echo "\$conn->close(); " >> /var/www/html/calldb.php
  echo "?>" >> /var/www/html/calldb.php
HEREDOC
}

resource "aws_instance" "database" {
  ami           = "${lookup(var.AmiLinux, var.region)}"
  instance_type = "t2.micro"
  associate_public_ip_address = "false"
  subnet_id = "${aws_subnet.PrivateAZA.id}"
  vpc_security_group_ids = ["${aws_security_group.Database.id}"]
  key_name = "awspoc"
  tags {
        Name = "database"
  }
  user_data = <<HEREDOC
  #!/bin/bash
  sleep 180
  yum update -y
  yum install -y mysql55-server
  service mysqld start
  /usr/bin/mysqladmin -u root password 'secret'
  mysql -u root -psecret -e "create user 'root'@'%' identified by 'secret';" mysql
  mysql -u root -psecret -e 'CREATE TABLE mytable (mycol varchar(255));' test
  mysql -u root -psecret -e "INSERT INTO mytable (mycol) values ('linuxacademythebest') ;" test
HEREDOC
}
