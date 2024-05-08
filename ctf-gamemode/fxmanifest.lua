fx_version 'bodacious'
game 'gta5'

author 'You'
version '1.0.0'

client_script { 
    'ctf_client.lua', 
    'ctf_rendering.lua' 
}
server_script 'ctf_server.lua'
shared_script { 
    'ctf_shared.lua',
    'ctf_config.lua'
}

files {
    'loadscreen/index.html',
    'loadscreen/css/loadscreen.css',
    'loadscreen/js/loadscreen.js',
    'loadscreen/css/bankgothic.ttf',
    'loadscreen/loadscreen.jpg'
}

loadscreen 'loadscreen/index.html'