# test
#
# one machine setup with weblogic 10.3.6 with BSU
# needs jdk7, orawls, orautils, fiddyspence-sysctl, erwbgy-limits puppet modules
#

node 'admin.example.com' {
  
   include os,java, ssh, orautils 
   include wls1036
   include wls1036_domain
   include wls_application_Cluster
   include wls_application_JMS
   include maintenance
   include packdomain
   
   Class['os']  -> 
     Class['ssh']  -> 
       Class['java']  -> 
         Class['wls1036'] -> 
           Class['wls1036_domain'] -> 
             Class['wls_application_Cluster'] -> 
               Class['wls_application_JMS'] ->
                 Class['packdomain']
}  

# operating settings for Middleware
class os {

  notice "class os ${operatingsystem}"

  $default_params = {}
  $host_instances = hiera('hosts', [])
  create_resources('host',$host_instances, $default_params)

  exec { "create swap file":
    command => "/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8192",
    creates => "/var/swap.1",
  }

  exec { "attach swap file":
    command => "/sbin/mkswap /var/swap.1 && /sbin/swapon /var/swap.1",
    require => Exec["create swap file"],
    unless => "/sbin/swapon -s | grep /var/swap.1",
  }

  #add swap file entry to fstab
  exec {"add swapfile entry to fstab":
    command => "/bin/echo >>/etc/fstab /var/swap.1 swap swap defaults 0 0",
    require => Exec["attach swap file"],
    user => root,
    unless => "/bin/grep '^/var/swap.1' /etc/fstab 2>/dev/null",
  }

  service { iptables:
        enable    => false,
        ensure    => false,
        hasstatus => true,
  }

  group { 'dba' :
    ensure => present,
  }

  # http://raftaman.net/?p=1311 for generating password
  # password = oracle
  user { 'wls' :
    ensure     => present,
    groups     => 'dba',
    shell      => '/bin/bash',
    password   => '$1$DSJ51vh6$4XzzwyIOk6Bi/54kglGk3.',
    home       => "/home/wls",
    comment    => 'wls user created by Puppet',
    managehome => true,
    require    => Group['dba'],
  }

  $install = [ 'binutils.x86_64','unzip.x86_64']


  package { $install:
    ensure  => present,
  }

  class { 'limits':
    config => {
               '*'       => {  'nofile'  => { soft => '2048'   , hard => '8192',   },},
               'wls'     => {  'nofile'  => { soft => '65536'  , hard => '65536',  },
                               'nproc'   => { soft => '2048'   , hard => '16384',   },
                               'memlock' => { soft => '1048576', hard => '1048576',},
                               'stack'   => { soft => '10240'  ,},},
               },
    use_hiera => false,
  }

  sysctl { 'kernel.msgmnb':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.msgmax':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.shmmax':                 ensure => 'present', permanent => 'yes', value => '2588483584',}
  sysctl { 'kernel.shmall':                 ensure => 'present', permanent => 'yes', value => '2097152',}
  sysctl { 'fs.file-max':                   ensure => 'present', permanent => 'yes', value => '6815744',}
  sysctl { 'net.ipv4.tcp_keepalive_time':   ensure => 'present', permanent => 'yes', value => '1800',}
  sysctl { 'net.ipv4.tcp_keepalive_intvl':  ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'net.ipv4.tcp_keepalive_probes': ensure => 'present', permanent => 'yes', value => '5',}
  sysctl { 'net.ipv4.tcp_fin_timeout':      ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'kernel.shmmni':                 ensure => 'present', permanent => 'yes', value => '4096', }
  sysctl { 'fs.aio-max-nr':                 ensure => 'present', permanent => 'yes', value => '1048576',}
  sysctl { 'kernel.sem':                    ensure => 'present', permanent => 'yes', value => '250 32000 100 128',}
  sysctl { 'net.ipv4.ip_local_port_range':  ensure => 'present', permanent => 'yes', value => '9000 65500',}
  sysctl { 'net.core.rmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.rmem_max':             ensure => 'present', permanent => 'yes', value => '4194304', }
  sysctl { 'net.core.wmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.wmem_max':             ensure => 'present', permanent => 'yes', value => '1048576',}

}

class ssh {
  require os

  notice 'class ssh'

  file { "/home/wls/.ssh/":
    owner  => "wls",
    group  => "dba",
    mode   => "700",
    ensure => "directory",
    alias  => "wls-ssh-dir",
  }
  
  file { "/home/wls/.ssh/id_rsa.pub":
    ensure  => present,
    owner   => "wls",
    group   => "dba",
    mode    => "644",
    source  => "/vagrant/ssh/id_rsa.pub",
    require => File["wls-ssh-dir"],
  }
  
  file { "/home/wls/.ssh/id_rsa":
    ensure  => present,
    owner   => "wls",
    group   => "dba",
    mode    => "600",
    source  => "/vagrant/ssh/id_rsa",
    require => File["wls-ssh-dir"],
  }
  
  file { "/home/wls/.ssh/authorized_keys":
    ensure  => present,
    owner   => "wls",
    group   => "dba",
    mode    => "644",
    source  => "/vagrant/ssh/id_rsa.pub",
    require => File["wls-ssh-dir"],
  }        
}

class java {
  require os

  notice 'class java'

  $remove = [ "java-1.7.0-openjdk.x86_64", "java-1.6.0-openjdk.x86_64" ]

  package { $remove:
    ensure  => absent,
  }

  include jdk7

  jdk7::install7{ 'jdk1.7.0_45':
      version              => "7u45" , 
      fullVersion          => "jdk1.7.0_45",
      alternativesPriority => 18000, 
      x64                  => true,
      downloadDir          => hiera('wls_download_dir'),
      urandomJavaFix       => true,
      sourcePath           => hiera('wls_source'),
  }

}

class wls1036{

   class { 'wls::urandomfix' :}

   $jdkWls11gJDK  = hiera('wls_jdk_version')
   $wls11gVersion = hiera('wls_version')
                       
   $puppetDownloadMntPoint = hiera('wls_source')                       
 
   $osOracleHome = hiera('wls_oracle_base_home_dir')
   $osMdwHome    = hiera('wls_middleware_home_dir')
   $osWlHome     = hiera('wls_weblogic_home_dir')
   $user         = hiera('wls_os_user')
   $group        = hiera('wls_os_group')
   $downloadDir  = hiera('wls_download_dir')
   $logDir       = hiera('wls_log_dir')     

  # set the defaults
  Wls::Installwls {
    version                => $wls11gVersion,
    fullJDKName            => $jdkWls11gJDK,
    oracleHome             => $osOracleHome,
    mdwHome                => $osMdwHome,
    user                   => $user,
    group                  => $group,    
    downloadDir            => $downloadDir,
    remoteFile             => hiera('wls_remote_file'),
    puppetDownloadMntPoint => $puppetDownloadMntPoint,
  }

  Wls::Nodemanager {
    wlHome       => $osWlHome,
    fullJDKName  => $jdkWls11gJDK,  
    user         => $user,
    group        => $group,
    serviceName  => $serviceName,  
    downloadDir  => $downloadDir, 
  }

  Wls::Bsupatch {
    mdwHome                => $osMdwHome,
    wlHome                 => $osWlHome,
    fullJDKName            => $jdkWls11gJDK,
    user                   => $user,
    group                  => $group,
    downloadDir            => $downloadDir, 
    puppetDownloadMntPoint => $puppetDownloadMntPoint, 
  }

  # install
  wls::installwls{'11gPS5':
     createUser   => false, 
  }
  
  # weblogic patch
  wls::bsupatch{'p17071663':
     patchId      => 'BYJ1',    
     patchFile    => 'p17071663_1036_Generic.zip',  
     require      => Wls::Installwls['11gPS5'],
  }

   #nodemanager configuration and starting
  wls::nodemanager{'nodemanager11g':
     listenPort    => hiera('domain_nodemanager_port'),
     listenAddress => hiera('domain_adminserver_address'),
     logDir        => $logDir,
     require       => Wls::Bsupatch['p17071663'],
  }
   
  orautils::nodemanagerautostart{"autostart ${wlsDomainName}":
      version     => "1111",
      wlHome      => $osWlHome, 
      user        => $user,
      logDir      => $logDir,
      require     => Wls::Nodemanager['nodemanager11g'];
  }

}

class wls1036_domain{


  $wlsDomainName   = hiera('domain_name')
  $wlsDomainsPath  = hiera('wls_domains_path_dir')
  $osTemplate      = hiera('domain_template')

  $adminListenPort = hiera('domain_adminserver_port')
  $nodemanagerPort = hiera('domain_nodemanager_port')
  $address         = hiera('domain_adminserver_address')

  $userConfigDir   = hiera('wls_user_config_dir')
  $jdkWls11gJDK    = hiera('wls_jdk_version')
                       
  $osOracleHome = hiera('wls_oracle_base_home_dir')
  $osMdwHome    = hiera('wls_middleware_home_dir')
  $osWlHome     = hiera('wls_weblogic_home_dir')
  $user         = hiera('wls_os_user')
  $group        = hiera('wls_os_group')
  $downloadDir  = hiera('wls_download_dir')
  $logDir       = hiera('wls_log_dir')     

  # install SOA OSB domain
  wls::wlsdomain{'Wls1036Domain':
    wlHome          => $osWlHome,
    mdwHome         => $osMdwHome,
    fullJDKName     => $jdkWls11gJDK, 
    wlsTemplate     => $osTemplate,
    domain          => $wlsDomainName,
    developmentMode => false,
    adminServerName => hiera('domain_adminserver'),
    adminListenAdr  => $address,
    adminListenPort => $adminListenPort,
    nodemanagerPort => $nodemanagerPort,
    wlsUser         => hiera('wls_weblogic_user'),
    password        => hiera('domain_wls_password'),
    user            => $user,
    group           => $group,    
    logDir          => $logDir,
    downloadDir     => $downloadDir, 
    reposDbUrl      => $reposUrl,
    reposPrefix     => $reposPrefix,
    reposPassword   => $reposPassword,
  }

  # start AdminServers for configuration of WLS Domain
  wls::wlscontrol{'startAdminServer':
    wlsDomain     => $wlsDomainName,
    wlsDomainPath => "${wlsDomainsPath}/${wlsDomainName}",
    wlsServer     => "AdminServer",
    action        => 'start',
    wlHome        => $osWlHome,
    fullJDKName   => $jdkWls11gJDK,  
    wlsUser       => hiera('wls_weblogic_user'),
    password      => hiera('domain_wls_password'),
    address       => $address,
    port          => $nodemanagerPort,
    user          => $user,
    group         => $group,
    downloadDir   => $downloadDir,
    logOutput     => true, 
    require       => Wls::Wlsdomain['Wls1036Domain'],
  }

  # create keystores for automatic WLST login
  wls::storeuserconfig{
   'Wls1036Domain_keys':
    wlHome        => $osWlHome,
    fullJDKName   => $jdkWls11gJDK,
    domain        => $wlsDomainName, 
    address       => $address,
    wlsUser       => hiera('wls_weblogic_user'),
    password      => hiera('domain_wls_password'),
    port          => $adminListenPort,
    user          => $user,
    group         => $group,
    userConfigDir => $userConfigDir, 
    downloadDir   => $downloadDir, 
    require       => Wls::Wlscontrol['startAdminServer'],
  }

}

class maintenance {

  $osOracleHome = hiera('wls_oracle_base_home_dir')
  $osMdwHome    = hiera('wls_middleware_home_dir')
  $osWlHome     = hiera('wls_weblogic_home_dir')
  $user         = hiera('wls_os_user')
  $group        = hiera('wls_os_group')
  $downloadDir  = hiera('wls_download_dir')
  $logDir       = hiera('wls_log_dir')     

  $mtimeParam = "1"


  cron { 'cleanwlstmp' :
    command => "find /tmp -name '*.tmp' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/tmp_purge.log 2>&1",
    user    => $user,
    hour    => 06,
    minute  => 25,
  }

  cron { 'mdwlogs' :
    command => "find ${osMdwHome}/logs -name 'wlst_*.*' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/wlst_purge.log 2>&1",
    user    => $user,
    hour    => 06,
    minute  => 30,
  }

}

class wls_application_Cluster {

  $wlsDomainName   = hiera('domain_name')
  $wlsDomainsPath  = hiera('wls_domains_path_dir')
  $osTemplate      = hiera('domain_template')

  $adminListenPort = hiera('domain_adminserver_port')
  $nodemanagerPort = hiera('domain_nodemanager_port')
  $address         = hiera('domain_adminserver_address')

  $userConfigDir   = hiera('wls_user_config_dir')
  $jdkWls11gJDK    = hiera('wls_jdk_version')
                       
  $osOracleHome = hiera('wls_oracle_base_home_dir')
  $osMdwHome    = hiera('wls_middleware_home_dir')
  $osWlHome     = hiera('wls_weblogic_home_dir')
  $user         = hiera('wls_os_user')
  $group        = hiera('wls_os_group')
  $downloadDir  = hiera('wls_download_dir')
  $logDir       = hiera('wls_log_dir')     
  
  $userConfigFile = "${userConfigDir}/${user}-${wlsDomainName}-WebLogicConfig.properties"
  $userKeyFile    = "${userConfigDir}/${user}-${wlsDomainName}-WebLogicKey.properties"
  
  # default parameters for the wlst scripts
  Wls::Wlstexec {
    wlsDomain      => $wlsDomainName,
    wlHome         => $osWlHome,
    fullJDKName    => $jdkWls11gJDK,  
    user           => $user,
    group          => $group,
    address        => $address,
    userConfigFile => $userConfigFile,
    userKeyFile    => $userKeyFile,
    port           => $adminListenPort,
    downloadDir    => $downloadDir,
    logOutput      => false, 
  }


  # create machine
  wls::wlstexec { 
    'createMachineNode1':
     wlstype       => "machine",
     wlsObjectName => "node1",
     script        => 'createMachine.py',
     params        => ["machineName      = 'node1'",
                       "machineDnsName   = '10.10.10.100'",
                      ],
  }

  # create machine
  wls::wlstexec { 
    'createMachineNode2':
     wlstype       => "machine",
     wlsObjectName => "node2",
     script        => 'createMachine.py',
     params        => ["machineName      = 'node2'",
                       "machineDnsName   = '10.10.10.200'",
                      ],
     require        => Wls::Wlstexec['createMachineNode1'],
  }
  
  
    # create managed server 1
    wls::wlstexec { 
      'createManagerServerWlsServer1':
       wlstype       => "server",
       wlsObjectName => "wlsServer1",
       script        => 'createServer.py',
       params        => ["javaArguments    = '-XX:PermSize=256m -XX:MaxPermSize=512m -Xms1024m -Xmx1024m -Dweblogic.Stdout=/data/logs/wlsServer1.out -Dweblogic.Stderr=/data/logs/wlsServer1_err.out'",
                         "wlsServerName    = 'wlsServer1'",
                         "machineName      = 'node1'",
                         "listenPort       = 9201",
                         "listenAddress    = '10.10.10.100'",
                         "nodeMgrLogDir    = '/data/logs'",
                        ],
      require        => Wls::Wlstexec['createMachineNode2'],
    }
  
    # create managed server 2
    wls::wlstexec { 
      'createManagerServerWlsServer2':
       wlstype       => "server",
       wlsObjectName => "wlsServer2",
       script        => 'createServer.py',
       params        => ["javaArguments    = '-XX:PermSize=256m -XX:MaxPermSize=512m -Xms1024m -Xmx1024m -Dweblogic.Stdout=/data/logs/wlsServer2.out -Dweblogic.Stderr=/data/logs/wlsServer2_err.out'",
                         "wlsServerName    = 'wlsServer2'",
                         "machineName      = 'node2'",
                         "listenPort       = 9201",
                         "listenAddress    = '10.10.10.100'",
                         "nodeMgrLogDir    = '/data/logs'",
                        ],
      require        => Wls::Wlstexec['createManagerServerWlsServer1'],
    }
  
    # create cluster
    wls::wlstexec { 
      'createClusterWeb':
       wlstype       => "cluster",
       wlsObjectName => "WebCluster",
       script        => 'createCluster.py',
       params        => ["clusterName      = 'WebCluster'",
                         "clusterNodes     = 'wlsServer1,wlsServer2'",
                        ],
      require        => Wls::Wlstexec['createManagerServerWlsServer2'],
    }



}

class wls_application_JMS{

  $wlsDomainName   = hiera('domain_name')
  $wlsDomainsPath  = hiera('wls_domains_path_dir')
  $osTemplate      = hiera('domain_template')

  $adminListenPort = hiera('domain_adminserver_port')
  $nodemanagerPort = hiera('domain_nodemanager_port')
  $address         = hiera('domain_adminserver_address')

  $userConfigDir   = hiera('wls_user_config_dir')
  $jdkWls11gJDK    = hiera('wls_jdk_version')
                       
  $osOracleHome = hiera('wls_oracle_base_home_dir')
  $osMdwHome    = hiera('wls_middleware_home_dir')
  $osWlHome     = hiera('wls_weblogic_home_dir')
  $user         = hiera('wls_os_user')
  $group        = hiera('wls_os_group')
  $downloadDir  = hiera('wls_download_dir')
  $logDir       = hiera('wls_log_dir')     
  
  $userConfigFile = "${userConfigDir}/${user}-${wlsDomainName}-WebLogicConfig.properties"
  $userKeyFile    = "${userConfigDir}/${user}-${wlsDomainName}-WebLogicKey.properties"

  # default parameters for the wlst scripts
  Wls::Wlstexec {
    wlsDomain      => $wlsDomainName,
    wlHome         => $osWlHome,
    fullJDKName    => $jdkWls11gJDK,  
    user           => $user,
    group          => $group,
    address        => $address,
    userConfigFile => $userConfigFile,
    userKeyFile    => $userKeyFile,
    port           => $adminListenPort,
    downloadDir    => $downloadDir,
    logOutput      => true, 
  }
  
  # create jms server for wlsServer1 
  wls::wlstexec { 
    'createJmsServerServer1':
     wlstype       => "jmsserver",
     wlsObjectName => "jmsServer1",
     script        => 'createJmsServer.py',
     params        =>  ["serverTarget   = 'wlsServer1'",
                        "jmsServerName  = 'jmsServer1'",
                        ],
  }
  # create jms server for wlsServer2 
  wls::wlstexec { 
    'createJmsServerServer2':
     wlstype       => "jmsserver",
     wlsObjectName => "jmsServer2",
     script        => 'createJmsServer.py',
     params        =>  ["serverTarget   = 'wlsServer2'",
                        "jmsServerName  = 'jmsServer2'",
                       ],
     require       => Wls::Wlstexec['createJmsServerServer1'];
  }

  # create jms module for WebCluster 
  wls::wlstexec { 
    'createJmsModuleServer':
     wlstype       => "jmsmodule",
     wlsObjectName => "jmsModule",
     script        => 'createJmsModule.py',
     params        =>  ["target         = 'WebCluster'",
                        "jmsModuleName  = 'jmsModule'",
                        "targetType     = 'Cluster'",
                       ],
     require       => Wls::Wlstexec['createJmsServerServer2'];
  }

  # create jms subdeployment for jms module 
  wls::wlstexec { 
    'createJmsSubDeploymentWLSforJmsModule':
     wlstype       => "jmssubdeployment",
     wlsObjectName => "jmsModule/JmsServer",
     script        => 'createJmsSubDeployment.py',
     params        => ["target         = 'jmsServer1,jmsServer2'",
                       "jmsModuleName  = 'jmsModule'",
                       "subName        = 'JmsServer'",
                       "targetType     = 'JMSServer'"
                      ],
     require     => Wls::Wlstexec['createJmsModuleServer'];
  }

  # create jms connection factory for jms module 
  wls::wlstexec { 
    'createJmsConnectionFactoryforJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "cf",
     script        => 'createJmsConnectionFactory.py',
     params        => ["jmsModuleName     = 'jmsModule'",
                       "cfName            = 'cf'",
                       "cfJNDIName        = 'jms/cf'",
                       "transacted        = 'false'",
                       "timeout           = 'xxxx'"
                      ],
     require     => Wls::Wlstexec['createJmsSubDeploymentWLSforJmsModule'];
  }

  # create jms error Queue for jms module 
  wls::wlstexec { 
    'createJmsErrorQueueforJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "ErrorQueue",
     script        => 'createJmsQueueOrTopic.py',
     params        => ["subDeploymentName = 'JmsServer'",
                       "jmsModuleName     = 'jmsModule'",
                       "jmsName           = 'ErrorQueue'",
                       "jmsJNDIName       = 'jms/ErrorQueue'",
                       "jmsType           = 'queue'",
                       "distributed       = 'true'",
                       "balancingPolicy   = 'Round-Robin'",
                       "useRedirect       = 'false'",
                      ],
     require     => Wls::Wlstexec['createJmsConnectionFactoryforJmsModule'];
  }

  # create jms Queue for jms module 
  wls::wlstexec { 
    'createJmsQueueforJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "Queue1",
     script        => 'createJmsQueueOrTopic.py',
     params        => ["subDeploymentName   = 'JmsServer'",
                       "jmsModuleName       = 'jmsModule'",
                       "jmsName             = 'Queue1'",
                       "jmsJNDIName         = 'jms/Queue1'",
                       "jmsType             = 'queue'",
                       "distributed         = 'true'",
                       "balancingPolicy   = 'Round-Robin'",
                       "useRedirect         = 'true'",
                       "limit               = 3",
                       "deliveryDelay       = 2000",
                       "timeToLive          = 300000",
                       "policy              = 'Redirect'",
                       "errorObject         = 'ErrorQueue'"
                      ],
     require     => Wls::Wlstexec['createJmsErrorQueueforJmsModule'];
  }

  # create jms Topic for jms module 
  wls::wlstexec { 
    'createJmsTopicforJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "Topic1",
     script        => 'createJmsQueueOrTopic.py',
     params        => ["subDeploymentName   = 'JmsServer'",
                       "jmsModuleName       = 'jmsModule'",
                       "jmsName             = 'Topic1'",
                       "jmsJNDIName         = 'jms/Topic1'",
                       "jmsType             = 'topic'",
                       "distributed         = 'true'",
                       "balancingPolicy     = 'Round-Robin'",
                      ],
     require     => Wls::Wlstexec['createJmsQueueforJmsModule'];
  }

  # create jms Queue for jms module 
  wls::wlstexec { 
    'createJmsQueue2forJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "Queue2",
     script        => 'createJmsQueueOrTopic.py',
     params        => ["subDeploymentName   = 'JmsServer'",
                       "jmsModuleName       = 'jmsModule'",
                       "jmsName             = 'Queue2'",
                       "jmsJNDIName         = 'jms/Queue2'",
                       "jmsType             = 'queue'",
                       "distributed         = 'true'",
                       "balancingPolicy     = 'Round-Robin'",
                       "useLogRedirect      = 'true'",
                       "loggingPolicy       = '%header%,%properties%'",
                       "limit               = 3",
                       "deliveryDelay       = 2000",
                       "timeToLive          = 300000",
                      ],
     require     => Wls::Wlstexec['createJmsTopicforJmsModule'];
  }

  # create jms Queue for jms module 
  wls::wlstexec { 
    'createJmsQueue3forJmsModule':
     wlstype       => "jmsobject",
     wlsObjectName => "Queue3",
     script        => 'createJmsQueueOrTopic.py',
     params        => ["subDeploymentName   = 'JmsServer'",
                       "jmsModuleName       = 'jmsModule'",
                       "jmsName             = 'Queue3'",
                       "jmsJNDIName         = 'jms/Queue3'",
                       "jmsType             = 'queue'",
                       "distributed         = 'true'",
                       "balancingPolicy     = 'Round-Robin'",
                       "timeToLive          = 300000",
                      ],
     require     => Wls::Wlstexec['createJmsQueue2forJmsModule'];
  }

}

class packdomain {

  $wlsDomainName   = hiera('domain_name')
  $jdkWls11gJDK    = hiera('wls_jdk_version')
                       
  $osMdwHome       = hiera('wls_middleware_home_dir')
  $osWlHome        = hiera('wls_weblogic_home_dir')
  $user            = hiera('wls_os_user')
  $group           = hiera('wls_os_group')
  $downloadDir     = hiera('wls_download_dir')

  wls::packdomain{'packWlsDomain':
      wlHome          => $osWlHome,
      mdwHome         => $osMdwHome,
      fullJDKName     => $jdkWls11gJDK,  
      user            => $user,
      group           => $group,    
      downloadDir     => $downloadDir, 
      domain          => $wlsDomainName,
  }
}

