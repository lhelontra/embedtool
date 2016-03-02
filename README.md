# Embedtool 
Script para auxiliar na customização de firmwares, utiliza o ambiente da imagem/diretório para fazer crosscompiler.
A premissa é, utilizar uma imagem ou diretório com o sistema para fazer as operações de crosscompiler/customização, e por fim, gerar a imagem desejada.
# A estrutura do embedtool é simples:
        targets
          Nome da placa
            config: Arquivo que contém as diretrizes para montar imagem/diretório, tamanho do boot, tipo de formato de cada partição e etc... 

            afterGenImg.sh: Após ser gerada a imagem e formatada, é invocado o script. É utilizado para manipular a imagem montada. 

            afterCopyingData.sh: É invocado após a cópia do dados para a imagem. É utilizado para manipular arquivos da imagem final.

# Parâmetros:
        Usage: ./embedtool.sh [-l|--targetlist] [-v|--verbose] [-d|--appendpath] [-t|--target <target>] [-s|--shared <shared diretory>] [options]
        Options:
        -l, --targetlist                                                             lists the supported targets.
        -v, --verbose                                                                enable verbose.
        -ap, --appendpath                                                            Append target path.
        -t, --target <machine>                                                       load target config file. (default     target: Null | default: config diretory: ./targets/)
        -m, --mount <imgfile|device> <mount_point_dir>                               mount source to mount point diretory.
        -u, --umount <mount_point_dir>                                               umount image mounted.
        -cp,--copy <device|image> <device destination|destination diretory>          copy data sorce to destination.
        -bimg, --buildimg <system diretory> <imagename>                              build image for target using diretory.
        -c, --chroot <imgfile|diretory> ["cmd"]                                      chroot in image or diretory and mount shared diretory and/or execute command using image enviroment. Use with in shared diretory.
        -s, --shared <shared diretory>                                               shared diretory for using with --chroot. Mount inside chroot image/diretory.

# Pré-requisitos:
Em um sistema baseado no Debian, certifique-se que os seguintes pacotes estão instalados:
```
apt-get install qemu qemu-user-static binfmt-support rsync kpartx
```

Exemplos:

# montar uma imagem:
        # ./embedtool.sh -v -t rpi -m 2015-11-12-jessie-minibian.img /mnt/rpi/
        [info] Loading target config: rpi.
        [info] Mounting image / at /mnt/rpi//.
        [info] Sector offset 125056 - Byte offset 64028672.
        [info] Sector offset 16 - Byte offset 8192.
        [info] Mounting image /boot at /mnt/rpi/boot.

# montar o cartão de memória:
        # ./embedtool.sh -v -t rpi -m /dev/sdb /mnt/rpi/
        [info] Loading target config: rpi.
        [info] Mounting /dev/sdb2 at /mnt/rpi/.
        [info] Mounting /dev/sdb1 at /mnt/rpi/boot.

# desmontar um cartão de memória/imagem:
        # ./embedtool.sh -v -t rpi -u /mnt/rpi/
        [info] Loading target config: rpi.
        [info] Umounting: /mnt/rpi/boot.
        [info] Umounting: /mnt/rpi/.

# Copiar os dados do cartão de memória para uma pasta:
        # ./embedtool.sh -v -t rpi --copy /dev/sdb sdcard
        [info] Loading target config: rpi.
        [info] Mounting /dev/sdb2 at /tmp/.embedtool3782.
        [info] Mounting /dev/sdb1 at /tmp/.embedtool3782//boot.
        [info] copying /dev/sdb to sdcard.
        [info] Umounting: /tmp/.embedtool3782//boot.
        [info] Umounting: /tmp/.embedtool3782.
        [info] done.

# Copiar uma imagem para o cartão de memória:
        # ./embedtool.sh -v -t rpi --copy 2015-11-12-jessie-minibian.img /dev/sdb
        [info] Loading target config: rpi.
        [info] recording 2015-11-12-jessie-minibian.img to /dev/sdb.
        [info] done.

# Utilizando o chroot em uma imagem
        # ./embedtool.sh -v -t rpi -s /home/leonardo/ -c 2015-11-21-raspbian-jessie-lite.img 
        [info] Loading target config: rpi.
        [info] Mounting image / at /tmp/.embedtool28911/.
        [info] Sector offset 131072 - Byte offset 67108864.
        [info] Sector offset 8192 - Byte offset 4194304.
        [info] Mounting image /boot at /tmp/.embedtool28911//boot.
        [info] Mounting shared diretory at /mnt.
        [info] Disable /tmp/.embedtool28911/etc/ld.so.preload ....
        [info] copying qemu-arm-static ...
        root@QemuArm-armv7l ~ #: uname -a
        Linux notebookPc 3.16.0-4-amd64 #1 SMP Debian 3.16.7-ckt20-1+deb8u2 (2016-01-02) armv7l GNU/Linux

        Compilando um programa em C, fiz um teste no /tmp:
        pico /tmp/testing.c
        #include <stdio.h>

        int main(void) {
                        printf("OK\n");
                        return 0;
        }

        # ./embedtool.sh -v -t rpi -s /tmp -c 2015-11-21-raspbian-jessie-lite.img "gcc testing.c -o testing"
        [info] Loading target config: rpi.
        [info] Mounting image / at /tmp/.embedtool25639/.
        [info] Sector offset 131072 - Byte offset 67108864.
        [info] Sector offset 8192 - Byte offset 4194304.
        [info] Mounting image /boot at /tmp/.embedtool25639//boot.
        [info] Mounting shared diretory at /mnt.
        [info] Disable /tmp/.embedtool25639/etc/ld.so.preload ....
        [info] copying qemu-arm-static ...
        [info] Launching command: gcc testing.c -o testing.
        [info] Reactivate /tmp/.embedtool25639/etc/ld.so.preload ....
        [info] Removing qemu-arm-static.
        [info] Umounting shared diretory: /tmp/.embedtool25639//mnt.
        [info] Umounting: /tmp/.embedtool25639//boot.
        [info] Umounting: /tmp/.embedtool25639.

        # file /tmp/testing
        /tmp/testing: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter       
        /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.32, BuildID[sha1]=6d9ee3266693f1e9d69d5486a957f7cdc4447b67, not stripped

        # ldd /tmp/testing
        libc.so.6 => /lib/arm-linux-gnueabihf/libc.so.6 (0xf6689000)
        /lib/ld-linux-armhf.so.3 (0xf6fcf000)

# Construir uma imagem personalizada a partir de um diretório que contém o sistema:
        # ./embedtool.sh -v -t rpi -bimg sdcard/ jessie-minibian-modified.img
        [info] Loading target config: rpi.
        [info] Target image: jessie-minibian-modified.img | Target diretory: sdcard/.
        [info] Creating jessie-minibian-modified.img with boot size: 64MB | root size: 1091MB | Reserved blocks: 5%.
        [info] Partitiong image...
        [info] Mapping devices....
        [info] Formating /dev/mapper/loop0p1.
        [info] Formating /dev/mapper/loop0p2.
        [info] executing afterGenImg.sh.
        [info] Creating /tmp/.embedtool8342...
        [info] Mounting /dev/mapper/loop0p2 at /tmp/.embedtool8342.
        [info] Mounting /dev/mapper/loop0p1 at /tmp/.embedtool8342//boot.
        [info] Copying sdcard/ to /tmp/.embedtool8342.
        [info] executing afterCopyingData.sh.
        [info] Umounting /tmp/.embedtool8342...
        [info] Deleting loop devices...
        [info] jessie-minibian-modified.img generated.
