
env_file="$(dirname "$0")/.env"

if [ ! -f "${env_file}" ];then
 echo "missed .env"
 exit 1
fi

echo Load pagent ssh keys
eval $(/usr/bin/ssh-pageant -r -a "/tmp/.ssh-pageant-$USERNAME")
ssh-add -l >/dev/null


source "${env_file}"
echo "Rsync started"
rsync.exe  -zar -e "ssh.exe -p 22 " --exclude=.svn --exclude=.cvs --exclude=.idea --exclude=.DS_Store --exclude=.git --exclude=.hg --exclude=*.hprof --exclude=*.pyc --exclude=../../http/iso --exclude=../../http/boots ./ dev@node01.x-server.net:/home/dev/repo/iPXE-boot
echo "Rsync finished"
