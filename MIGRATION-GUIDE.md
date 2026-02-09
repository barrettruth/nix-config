After migration is complete, undo the temporary access grants:

    sudo gpasswd -d frozen barrett
    sudo chmod 750 /home/barrett
