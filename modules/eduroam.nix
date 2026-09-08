{ pkgs, ... }:
# Download pkcs12 file from http://www.easyroam.de/
# Scripts are from https://doku.tid.dfn.de/de:eduroam:easyroam#extrahieren_der_erforderlichen_zertifikate_aus_der_easyroam_pkcs12_datei
let
  easyroam_extract = pkgs.writeShellScriptBin "easyroam_extract" ''
    #!/bin/bash
    # This script extract all the necessary information from the easyroam PKCS12 File and put it under /etc/easyroam-certs

    # Usage:   bash easyroam_extract.sh <YOUR-PKCS12-File>
    set -e

    # check if we are root

    if [[ $EUID -ne 0 ]]; then
      echo "You must be root to run easyroam_extract.sh." 1>&2
      exit 100
    fi


    ConfDir="/etc/easyroam-certs"

    [ -d "$ConfDir" ] || mkdir -p "$ConfDir"

    # check input file

    if [ -z "$1" ]; then
            echo ""
            echo "Your pkcs12 file is missed as input parameter."
            echo ""
            exit 1
    else
            InputFile="$1"
    fi
    # set openssl legacy options if necessary

    LegacyOption=
    OpenSSLversion=$(openssl version | awk '{print $2}' | sed -e 's/\..*$//')
    if [ "$OpenSSLversion" -eq "3" ]; then
            LegacyOption="-legacy"
    fi

    # check pkcs12 file

    Pwd="pkcs12"

    if ! openssl pkcs12 -in "$InputFile" $LegacyOption -info -passin pass: -passout pass:"$Pwd" > /dev/null 2>&1; then
            echo ""
            echo "ERROR: The given input file does not seem to be a valid pkcs12 file."
            echo ""
            exit 1
    fi


    # extract key, cert, ca and identity

    openssl pkcs12 -in "$InputFile" -clcerts $LegacyOption -nokeys -passin pass: -out "$ConfDir/easyroam_client_cert.pem"
    openssl pkcs12 -in "$InputFile" $LegacyOption -nocerts -passin pass: -passout pass:"$Pwd" -out "$ConfDir/easyroam_client_key.pem"
    openssl pkcs12 -info -in "$InputFile" $LegacyOption -cacerts -nokeys -passin pass: -out "$ConfDir/easyroam_root_ca.pem" > /dev/null 2>&1
    openssl x509 -noout -in "$ConfDir/easyroam_client_cert.pem" -subject | awk -F \, '{print $6}' | sed -e 's/.*=//' -e 's/\s*//' >  "$ConfDir/identity"
    echo "Done."

  '';

  easyroam_nmcli = pkgs.writeShellScriptBin "easyroam_nmcli" ''
        #!/bin/bash

        # Usage: bash   easyroam_nmcli.sh

        set -e

        # check if we are root

        if [[ $EUID -ne 0 ]]; then
            echo "You must be root to run easyroam_nmcli.sh." 1>&2
            exit 100
        fi

        # check for easyroam-cert files

        [ -d /etc/easyroam-certs ] && ConfDir=/etc/easyroam-certs || { echo "Aborted, run easyroam_extract.sh first!"; exit 1;  }
        [ -f /etc/easyroam-certs/easyroam_client_cert.pem ] ||  { echo "Aborted, client_cert missing."; exit 1;  }
        [ -f /etc/easyroam-certs/easyroam_root_ca.pem ] ||  { echo "Aborted, root_ca missing."; exit 1;  }
        [ -f /etc/easyroam-certs/easyroam_client_key.pem ] ||  { echo "Aborted, client_key missing."; exit 1;  }
        [ -f /etc/easyroam-certs/identity ] && Identity=$(cat "$ConfDir/identity") ||  { echo "Aborted, identity missing"; exit 1;  }

        Pwd="pkcs12"
        # check for nmcli

        if ! type nmcli >/dev/null 2>&1; then
                echo ""
                echo "ERROR: nmcli not found!" >&2
                echo "This wizard assumes that your network connections are NOT managed by NetworkManager." >&2
                echo ""
                exit 1
        fi

        # check for wifi device

        if ! nmcli -g TYPE,DEVICE device | grep wifi >/dev/null; then
                echo ""
                echo "ERROR: Unable to find any wifi device!" >&2
                echo ""
                exit 1
        fi


        # configure parameters

        WIntName=$(iw dev | awk '$1=="Interface"{print $2}')

        WOn="GENERAL.STATE:"

        WLANName="eduroam"

        ALT_SUBJECT="DNS:easyroam.eduroam.de"

        # TLS_1.3
        TLS_VERSION="0x100"

        # Remove existing connections

        nmcli connection show | \
                awk '$1==c{ print $2 }' c="$WLANName" | \
                xargs -rn1 nmcli connection delete uuid

        # switch wlan on

        nmcli dev show "$WIntName" | \
              awk '$1==c{ print $2 }' c="$WOn" | \
              xargs -rn1 nmcli radio wifi on

        # Create new connection

        nmcli connection add \
                type wifi \
                con-name "$WLANName" \
                ssid "$WLANName" \
                -- \
                wifi-sec.key-mgmt wpa-eap \
                802-1x.eap tls \
                802-1x.altsubject-matches "$ALT_SUBJECT" \
                802-1x.phase1-auth-flags "$TLS_VERSION" \
                802-1x.identity "$Identity" \
                802-1x.ca-cert "$ConfDir/easyroam_root_ca.pem" \
                802-1x.client-cert "$ConfDir/easyroam_client_cert.pem" \
                802-1x.private-key-password "$Pwd" \
                802-1x.private-key "$ConfDir/easyroam_client_key.pem"

    		chmod 600 /etc/easyroam-certs/easyroam_client_key.pem
    		chmod 644 /etc/easyroam-certs/*.pem
    		chown root:root /etc/easyroam-certs/*
  '';
in
{
  environment.systemPackages = with pkgs; [
    openssl
    iw

    easyroam_extract
    easyroam_nmcli
  ];
}
