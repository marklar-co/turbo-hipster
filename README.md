turbo-hipster: a vagrant box for running abe and multiple blockchain nodes. Written by hipsters, for hipsters.

##QUICKSTART

3. Install VirtualBox (from a website download) then `brew install vagrant`, then try a [simple vagrant tutorial](http://docs.vagrantup.com/v2/getting-started/index.html) to familiarise yourself with it. It shouldn't take long, just spend like 10-20 minutes on this excluding time downloading VM images. Then run `vagrant up`. If you encounter any errors with vagrant up, save the terminal output and `guest_logs/vagrant_mmc_bootstrap.log`.

4. If there were no problems, pop into your development VM by running `vagrant ssh`. From now on, all commands are run within the VM.

5. Check that the daemons are running with
    ```
    ps aux | grep bitcoin
    ps aux | grep lite
    ps aux | grep doge
    ps aux | grep florin
    ```
    if not, run
    ```
    /opt/bitcoin/bitcoind
    /opt/dogecoin/litecoind
    /opt/dogecoin/dogecoind
    /opt/florincoin/florincoind
    ```
    (they should run as a daemons).

6. Check the progress of the node syncing the blockchain by running `chain_progress`. The output will be something like:
    ```
    {'chains': {'bitcoin_testnet': '0.000001',
                'dogecoin_testnet': '0.608287',
                'florincoin': None,
                'litecoin_testnet': '0.474797'},
      'timestamp': 'Wed Jun 17 08:58:16 2015'}
    ```
    Keep an eye on the progress indicators. If there's been too little progress here, abe freaks out, so let it reach something like 0.95 before continuing to the next step.

7. Abe needs to be run in two phases; first in "init" mode where it reads the dogecoin data directly, then in "rpc" mode where it communicates with dogecoind through rpc.

8. For "init" mode, run:
    ```
    python -m Abe.abe --config /vagrant/conf/abe-init.conf --commit-bytes 100000 --no-serve
    ```

9. Leave that for a couple of minutes, and then you shouldn't ever have to run it again. Then ctrl-c and run "rpc" mode with:
    ```
    python -m Abe.abe --config /vagrant/conf/abe-rpc.conf --commit-bytes 100000 --no-serve
    ```

10. Now play around with the system, and to stop abe simply ctrl-c. When you've made tweaks to the abe code, reinstall it:

    ```
    cd /vagrant/ThirdParty/abe && sudo python setup.py install
    ```

    If you want to clear out Abe's database and reinstall, just run `abe_clean` from anywhere.

    and run abe in rpc mode again (step 8). Repeat ad infinitum!

##UPDATING NODE BINARIES

Florincoin is stored in the repo as both:

- a submodule, pointing to a commit in http://github.com/florincoin/florincoin
- a locally built binary

For day-to-day development, we simply run the locally-built binary. If we need to take an update to florincoind, the process is:

1. Make sure you've got the submodules:

    ```
    git submodule sync --recursive
    git submodule update --init --recursive
    ```

2. Change to the submodule directory: `cd ThirdParty/florincoin`

3. Checkout the desired branch from the its remote repo and pull the latest changes:

    ```sh
    git checkout master
    git pull
    ```

5. Go back to the project root: `cd ..`

6. Commit the updated submodule: `git commit -am "Pulled down update to florincoin"`

6. Get back into the vagrant shell to rebuild from the new source: `vagrant ssh`. From now on, all commands are in the vagrant shell.

7. Make sure all the dependencies are installed:

    ```sh
    apt-get update
    apt-get install -y build-essential libssl-dev libdb-dev libdb++-dev libboost-all-dev libqrencode-dev libminiupnpc-dev
    ```

8. Build florincoin: `(cd /vagrant/ThirdParty/florincoin/src && make -f makefile.unix)`

9. Copy the binary into the binary directory: `cp /vagrant/ThirdParty/florincoin/src/florincoind /vagrant/ThirdParty/florincoin_bin/florincoin-<sha of commit>`

10. Drop out of the vagrant shell

10. Commit the new binary:

    ```
    git add ThirdParty/florincoin_bin/florincoind-<sha>
    git commit m "New florincoin binary: <sha>"
    ```