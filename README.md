turbo-hipster: a vagrant box for running abe and multiple blockchain nodes. Written by hipsters, for hipsters.

##QUICKSTART

1. Get submodules by issuing the following commands:
    ```
    git submodule sync --recursive
    git submodule update --init --recursive
    ```

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

6. Check the progress of the node syncing the blockchain by running `/vagrant/tools/chain_progress`. The output will be something like:
    ```
    {'chains': {'bitcoin_testnet': '0.000001',
                'dogecoin_testnet': '0.608287',
                'florincoin': None,
                'litecoin_testnet': '0.474797'},
      'timestamp': 'Wed Jun 17 08:58:16 2015'}
    ```
    Keep an eye on the progress indicators. If there's been too little progress here, abe freaks out, so let it reach something like 0.95 before continuing to the next step.

7. Abe needs to be run in two phases; first in "init" mode where it reads the dogecoin data directly, then in "rpc" mode where it communicates with dogecoind through rpc. For both, make sure your current working directory is `/vagrant` so that the `abe-*.conf` files are in the working directory.

8. For "init" mode, run:
    ```
    python -m Abe.abe --config abe-init.conf --commit-bytes 100000 --no-serve
    ```

9. Leave that for a couple of minutes, and then you shouldn't ever have to run it again. Then ctrl-c and run "rpc" mode with:
    ```
    python -m Abe.abe --config abe-rpc.conf --commit-bytes 100000 --no-serve
    ```

10. Now play around with the system, and to stop abe simply ctrl-c. When you've made tweaks to the abe code, reinstall it (step 5) and run abe in rpc mode again (step 8). Repeat ad infinitum!

11. When modifications are made to abe, reinstall it by doing the following:
    ```
    cd /vagrant/ThirdParty/abe && sudo python setup.py install
    ```
