# How to make your computer email you when mysql is down
This document will walk you through the steps required to receive email alerts when MySQL is unavailable on your machine, as a "hello world" exercise with Nagios.

Only a rudimentary single-machine monitoring deployment is considered here - for multi-machine monitoring and other things, please consult the [Nagios documentation](https://www.nagios.org/documentation).

## Sending email with Postfix through Gmail
If you already have Postfix set up, try the following command:
```sh
$ echo "hello world" | mail -s "Postfix test" <YOUR EMAIL ADDRESS>
```

If that works, then all is well and you can skip the rest of this section.

If not, the following will show you how to set up Postfix to work with a Gmail SMTP server. This will require saving your Gmail credentials in plain text on your server, so for the purpose of this exercise maybe you want to make a throwaway Gmail account.

1. The following steps assume you are root or use `sudo` appropriately.
2. Get things:
   ```sh
   $ DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils libsasl2-2 ca-certificates libsasl2-modules
   ```
3. Put a cert in place:
   ```sh
   $ cp /etc/ssl/certs/Thawte_Premium_Server_CA.pem /etc/postfix/cacert.pem
   ```
4. Append the following to the end of your `/etc/postfix/main.cf` file:
   ```
   relayhost = [smtp.gmail.com]:587
   smtp_sasl_auth_enable = yes
   smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
   smtp_sasl_security_options = noanonymous
   smtp_tls_CAfile = /etc/postfix/cacert.pem
   smtp_use_tls = yes
   ```
5. Create your credentials file:
   ```sh
   $ echo "[smtp.gmail.com]:587    USERNAMEFILLME@gmail.com:PASSWORDFILLME" > /etc/postfix/sasl_passwd
   $ chmod 400 /etc/postfix/sasl_passwd
   ```
6. Trigger changes (you may see a "overriding earlier entry: relayhost=" warning - that should be okay):
   ```sh
   $ postmap /etc/postfix/sasl_passwd
   $ /etc/init.d/postfix reload
   ```

Now try to send the email again:
```sh
$ echo "hello world" | mail -s "Postfix test" <YOUR EMAIL ADDRESS>
```
If it still does not work, troubleshoot and get it working before proceeding to the actual Nagios setup.

## Nagios "out of the box" set up
This section shows you how to get a "baseline" Nagios setup running.

1. The following steps assume you are root or use `sudo` appropriately.
2. Get things:
   ```sh
   $ DEBIAN_FRONTEND=noninteractive apt-get install -y nagios3 nagios-nrpe-plugin
   ```
3. Set up some baseline things: (Note the *nagiosadmin/nagiosadmin* credentials - just keeping it simple here, but set that as restrictive as you need. If you change the user name, you will need to tweak `/etc/nagios3/cgi.cfg` which has that username as default for lots of things.)
   ```sh
   $ usermod -a -G nagios www-data
   $ chmod -R +x /var/lib/nagios3/
   $ htpasswd -b -c /etc/nagios3/htpasswd.users nagiosadmin nagiosadmin
   ```
4. Edit `/etc/nagios3/nagios.cfg`, change the `check_external_commands=0` to `check_external_commands=1`.
5. Edit `/etc/nagios3/conf.d/contacts_nagios2.cfg`, change the `root@localhost` to whatever email address you want to receive notifications on.
6. Trigger changes:
   ```sh
   $ service nagios3 restart
   ```

Now point your browser to <your ip address>/nagios3, enter username/password *nagiosadmin*/*nagiosadmin* (unless you changed it), and voila, you should have a basic Nagios deployment good to go. Click on the **Services** link to see monitoring of *Current Load*, *Current Users*, *Disk Space*, *HTTP*, *SSH*, and *Total Processes*.

If it does not work troubleshoot and get it working before proceeding to the MySQL Abe monitoring setup.

## Monitor MySQL
Nagios ships with a built-in mysql plugin. To see it in action, simply run the following: (note for testing purposes I gave an empty root password to MySQL)
```sh
$ /usr/lib/nagios/plugins/check_mysql -u root
Uptime: 101  Threads: 1  Questions: 579  Slow queries: 0  Opens: 189  Flush tables: 1  Open tables: 41  Queries per second avg: 5.732|Connections=44c;;; Open_files=48;;; Open_tables=41;;; Qcache_free_memory=16759696;;; Qcache_hits=0c;;; Qcache_inserts=0c;;; Qcache_lowmem_prunes=0c;;; Qcache_not_cached=82c;;; Qcache_queries_in_cache=0;;; Queries=580c;;; Questions=575c;;; Table_locks_waited=0c;;; Threads_connected=1;;; Threads_running=1;;; Uptime=101c;;;
```

That's all there is to it. We simply need to tell Nagios to use this plugin.
1. The following steps assume you are root or use `sudo` appropriately.
2. Add the following to the bottom of your `/etc/nagios3/commands.cfg`: (don't forget to tweak that command with your actual mysql username and password)
   ```
   define command{
           command_name	check_mysql_as_root
           command_line	/usr/lib/nagios/plugins/check_mysql -u root
           }
   ```
3. Add the following to the bottom of your `/etc/nagios3/conf.d/localhost_nagios2.cfg`:
   ```
   define service{
           use                             generic-service
           host_name                       localhost
           service_description             MySQL Root Plugin Test
           check_command                   check_mysql_as_root
           }
   ```
4. Trigger changes:
   ```sh
   $ service nagios3 restart
   ```

Now once again point your browser to *http://<your ip address>/nagios3*, enter username/password *nagiosadmin*/*nagiosadmin* (unless you changed it), click on the **Services** link and in addition to the monitoring you saw before you will also see *MySQL Root Plugin Test*. It may be in state *Pending* or something when it first starts, give it a few minutes to stabilise.

Once it's in green with state *OK*, shut down MySQL on your machine:
```sh
$ service mysql stop
```
At the next monitoring interval (i.e. after a few minutes), the service should go red with *CRITICAL* in the **Services** page, and after a while you should receive an email with a subject like `** PROBLEM Service Alert: localhost/MySQL Root Plugin Test is CRITICAL **` that looks roughly like this:
```
***** Nagios *****

Notification Type: PROBLEM

Service: MySQL Root Plugin Test
Host: localhost
Address: 127.0.0.1
State: CRITICAL

Date/Time: Tue Jul 28 07:33:46 UTC 2015

Additional Info:

Cant connect to local MySQL server through socket /var/run/mysqld/mysqld.sock (2)
```

## Conclusion
Nagios is extremely configurable, but by this point you should have a basic but functioning monitoring foundation to build upon.
