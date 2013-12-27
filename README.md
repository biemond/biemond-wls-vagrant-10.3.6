biemond-orawls-vagrant
=======================

The reference implementation of https://github.com/biemond/biemond-wls  

uses CentOS 6.5 box with puppet 3.4.0

creates a patched 10.3.6 WebLogic cluster ( admin,node1 , node2 )


site.pp is located here:  
https://github.com/biemond/biemond-wls-vagrant-10.3.6/blob/master/puppet/manifests/site.pp  


used the following software
- jdk-7u45-linux-x64.tar.gz

weblogic 10.3.6
- wls1036_generic.jar
- p17071663_1036_Generic.zip

Using the following facts

- environment => "development"
- vm_type     => "vagrant"


# admin server  
vagrant up admin

# node1  
vagrant up node1

# node2  
vagrant up node2


Detailed vagrant steps (setup) can be found here:

http://vbatik.wordpress.com/2013/10/11/weblogic-12-1-2-00-with-vagrant/

For Mac Users.  The procedure has been and run tested on Mac.
