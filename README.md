# Server Setup Script

This script is used to set up a server and it accepts several command line arguments.

**ALL ARGUMENTS ARE OPTIONAL...** 

But you can use them if you need or want.

Updates are now in the changelog file if you want to read.

**Patcher is working now! Thanks to BUKK**

## Permissions

You have to give it permissions to run properly.

```sh
chmod +x server.sh
```

**You also must run this script as root or it won't work!**

## Usage

```sh
server.sh [-d PATH] [-a IP] [-u USER] [-v] [-p PORT] [-x] [-h]
```

## Options

- `-d PATH`: Set the directory where the server will be installed
- `-a IP`: Set the IP of the server for configuration
- `-u USER`: Set the username for the database
- `-v`: Set the VPS Mode on. This will get your external IP automatically.
- `-p PORT`: (EXPERIMENTAL/ADVANCED USERS ONLY) Set the PORT where the Gateway Server will be listening
- `-x`: unlock manual config for ports of the server, this mode is ONLY RECOMENDED FOR ADVANCED USERS and WILL REQUIRE further DB configuration!
- `-h`: Display this help message

## Examples

One-click install (to rule them all)

```sh
./server.sh
```

To install at **/root/gfserver/** directory

```sh
./server.sh -d /root/gfserver
```

To install with **kamael** as database user:

```sh
./server.sh -u kamael
```

To install with a predefined IP address such as `192.168.200.25`

```sh
./server.sh -a 192.168.200.25
```

To install with **kamael** as db user, at **/root/gfonline** directory and IP `192.168.2.4` as IP.

```sh
./server.sh -d /root/gfonline -a 192.168.2.4 -u kamael
```

## Expert Mode

To use expert mode you must use the flag `x`

```sh
./server.sh -x 
```

Important: you can use other flags with Expert Mode if you want.

In this mode you will be prompted for choosing **EVERY PORT** you can configure for the server. 

- Remember that this is experimental and should only be used by **ADVANCED USERS** who knows how to config the server and database.

## Known Bugs

- `wget` is pulling data from my little local webserver so the **download part won't work with this script right now**. I'm gonna upload it on a VPS or a private hosting soon, but now I'm killing bugs so you won't be disappointed.

> By the moment: NO WORKAROUND WILL HELP YOU since my script runs custom seds/things. So don't issue it yet.

- Validation of the input data won't run in a loop, so be careful with input.

- When trying to install multiple servers, if same folder is set, it overwrites the data and configs from the previous one. So be careful when doing that.

**FINAL ADVICE: THIS SCRIPT IS NOT INTENDED TO RUN MORE THAN 1 TIME PER MACHINE** so if you screw up something in the setup, you'd better restart your VM/VPS. (Or you can read the code and see where you messed up and try to fix if you know what you're doing)
