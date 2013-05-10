###### install RVM
---
$ curl -L get.rvm.io | bash -s stable --ruby
如果现在你在命令行输入rvm -v会提示你并没有安装rvm,原因是系统找不到rvm命令，
只要将路径加入PATH就行了

source ~/.rvm/scripts/rvm
现在输入rvm -v就会显示一下信息，说明安装成功

rvm 1.15.8 (stable) by Wayne E. Seguin <wayneeseguin@gmail.com>,
Michal Papis <mpapis@gmail.com> [https://rvm.io/]
##### install ruby

$ rvm install 1.9.3
查看已经安装的ruby版本信息

$ rvm list
显示的如下信息,表示安装了ruby1.9.3

rvm rubies
=* ruby-1.9.3-p194 [ x86_64 ]
# => - current
# =* - current && default
# * - default
##### uninstall ruby
首先查看你系统上安装来哪些ruby版本

rvm list
卸载你需要的版本

rvm remove ruby-1.9.3-p194
or rvm uninstall ruby-1.9.3-p194
最后同样用rvm list 查看是否已经卸载来你不需要的版本
###### 常见的错误 
---
当用gem install xxxx 安装任何ruby库的时候提示

ERROR: Loading command: install (LoadError) 

no such file to load — zlib 

uninitialized constant Gem::Commands::InstallCommand
解决方案：rvm官方给出了[详细说明](https://rvm.io/packages/zlib/)
如果出现no such file to load – openssl
解决方案：rvm官方同样给出了[详细说明](https://rvm.io/packages/openssl/)
