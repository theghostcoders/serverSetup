# Server Setup Script

This script is used to set up a server and it accepts several command line arguments.

## Permissions

You have to give it permissions to run properly.

```sh
chmod +x server.sh
```

**You also must run this script as root or it won't work!**

## Usage

```sh
setup.sh [-d PATH] [-a IP] [-p PORT] [-x] [-h]
```

## Options

- `-d PATH`: Set the directory where the server will be installed
- `-a IP`: Set the IP of the server for configuration
- `-u USER`: Set the username for the database
- `-p PORT`: (EXPERIMENTAL/ADVANCED USERS ONLY) Set the PORT where the Gateway Server will be listening
- `-x`: unlock manual config for ports of the server, this mode is ONLY RECOMENDED FOR ADVANCED USERS and WILL REQUIRE further DB configuration!
- `-h`: Display this help message

## Examples

To install at **/root/gfserver/** directory

```sh
./setup.sh -d /root/gfserver
```

To install with **kamael** as database user:

```sh
./setup.sh -u kamael
```

To install with a predefined IP address such as `192.168.200.25`

```sh
./setup.sh -a 192.168.200.25
```

To install with **kamael** as db user, at **/root/gfonline** directory and IP `192.168.2.4` as IP.

```sh
./setup.sh -d /root/gfonline -a 192.168.2.4 -u kamael
```

## Expert Mode

To use expert mode you must use the flag `x`

```sh
./setup.sh -x 
```

In this mode you will be prompted for choosing **EVERY PORT** you can configure for the server. 

- Remember that this is experimental and should only be used by **ADVANCED USERS** who knows how to config the server and database.

## Known Bugs

- `wget` is pulling data from my little local webserver so the **download part won't work with this script right now**. We'll upload it for a VPS or a private hosting soon.

- Patcher part is still a work in progress since it will not always replace with `sed` command. (If you know how to fix, help is really apreciated)

- Validation of the data won't run in a loop, so be careful with input.

- When trying to install multiple servers, if same folder is set, it overwrites the data and configs from the previous one.
