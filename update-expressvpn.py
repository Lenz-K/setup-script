import subprocess
import re
import os
import sys


NOT_INSTALLED = 'Not installed'
VERSION_REGEX = re.compile(r'\d+.\d+.\d+.\d+')


def execute_command(command_list):
    return subprocess.run(command_list, stdout=subprocess.PIPE).stdout.decode('utf-8')


def remove_file(file_name):
    if os.path.isfile(file_name):
        os.remove(file_name)


def retrieve_version():
    try:
        version_output = execute_command(['expressvpn', '--version'])
        result = VERSION_REGEX.search(version_output)

        if not result:
            print('Unexpected version format! Aborting!')
            return -1, None

        return 0, result.group()

    except FileNotFoundError:
        return 0, NOT_INSTALLED


def retrieve_latest_version():
    os.system('wget https://www.expressvpn.com/latest#linux')
    if not os.path.isfile('latest'):
        print('Unable to retrieve latest version online! Aborting!')
        print('No internet connection?')
        return -1, None

    regex = re.compile(r'https://www.expressvpn.works/clients/linux/expressvpn_\d+.\d+.\d+.\d+-1_amd64.deb.asc')

    with open('latest', 'rt') as file:
        text = '\n'.join(file.readlines())

    result = regex.search(text)
    remove_file('latest')

    if not result:
        print('Unable to retrieve latest version link! Aborting!')
        return -1, None

    link = result.group()
    result = VERSION_REGEX.search(link)
    if not result:
        print('Unable to retrieve latest version! Aborting!')
        return -1, None

    return 0, result.group()


def version_greater_than(latest_version, version):
    latest_version = latest_version.split('.')
    version = version.split('.')

    for lv, v in zip(latest_version, version):
        if int(lv) > int(v):
            return True
        elif int(lv) < int(v):
            return False

    return False


def install_expressvpn(version, distro):
    print(f'Installing expressvpn version {version}')

    if distro == 'Ubuntu':
        package_type = '.deb'
        arch = 'amd64'
        separator = '_'
    elif distro == 'Manjaro':
        package_type = '.pkg.tar.xz'
        arch = 'x86_64'
        separator = '-'
    else:
        print('Unsupported Linux distribution! Aborting!')
        return -1

    file_name = f'expressvpn{separator}{version}-1{separator}{arch}{package_type}'
    download_link = f'https://www.expressvpn.works/clients/linux/{file_name}'
    expected_fingerprint = '''pub   rsa4096 2016-01-22 [SC]
      1D0B 09AD 6C93 FEE9 3FDD  BD9D AFF2 A141 5F6A 3A38
uid           [ unknown] ExpressVPN Release <release@expressvpn.com>
sub   rsa4096 2016-01-22 [E]'''

    os.system(f'wget {download_link}')
    os.system(f'wget {download_link}.asc')

    os.system('gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 0xAFF2A1415F6A3A38')
    key_fingerprint = execute_command(['gpg', '--fingerprint', 'release@expressvpn.com']).strip()

    if key_fingerprint == expected_fingerprint:
        exit_code = os.system(f'gpg --verify {file_name}.asc')
        if exit_code == 0:
            if distro == 'Ubuntu':
                os.system(f'dpkg -i {file_name}')
            elif distro == 'Manjaro':
                os.system(f'pacman -U --noconfirm {file_name}')

            remove_file(file_name)
            remove_file(f'{file_name}.asc')
        else:
            print('Aborting ExpressVPN installation!')
            return -1
    else:
        print('The fingerprint of the downloaded ExpressVPN key is not as expected!')
        print('Aborting ExpressVPN installation!')
        return -1

    return 0


def main(argv):
    if len(argv) < 1:
        print('Linux Distribution (Ubuntu or Manjaro) must be given as first commandline argument!')
        return -1
    distro = argv[0]

    exit_code, version = retrieve_version()
    if exit_code < 0:
        return exit_code

    exit_code, latest_version = retrieve_latest_version()
    if exit_code < 0:
        return exit_code
    print(f'       Detected installed version: {version}')
    print(f'Detected latest available version: {latest_version}')

    if version == NOT_INSTALLED or version_greater_than(latest_version, version):
        exit_code = install_expressvpn(latest_version, distro)
        if version != NOT_INSTALLED:
            os.system('expressvpn connect')

    return exit_code


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
