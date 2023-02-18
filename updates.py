import os

# script pour regrouper les tâches habituelles mais répétitives sur mon mac


os.system("brew upgrade")                       # executer brew upgrade
os.system("gem update")                         # executer gem update
os.system("flutter upgrade")                    # faire la mise à jour de flutter
os.system("npm update -g")                      # faire la mise à jour de npm
os.system("pip3 install --upgrade pip")         # faire la mise à jour de pip

os.system("rvm get stable")
os.system("nvm install node")

os.system("xcode-select --install")             # faire les mises à jour de XCode
os.system("softwareupdate --install -a")


