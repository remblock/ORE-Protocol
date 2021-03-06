# ORE-Node-Monitor

#### This script will monitor your producer node:

***

#### Adjust the ore-node-monitor script using the code below:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-node-monitor.sh && sudo chmod u+x ore-node-monitor.sh && nano ./ore-node-monitor.sh
```

# ORE-Producer-Setup

#### This script will automatically setup your producer node.

***

#### Adjust the ore-bp1-mainnet script using the code below:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-bp1-mainnet.sh && sudo chmod u+x ore-bp1-mainnet.sh && nano ./ore-bp1-mainnet.sh
```

#### Adjust the ore-bp2-mainnet script using the code below:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-bp2-mainnet.sh && sudo chmod u+x ore-bp2-mainnet.sh && nano ./ore-bp2-mainnet.sh
```

***

# ORE-Take-Snapshot

#### This script will automatically take and transfer your snapshots, block logs and state history over to your web server.

***

#### Adjust the ore-take-snapshot script using the code below:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-take-snapshot.sh && sudo chmod u+x ore-take-snapshot.sh && nano ./ore-take-snapshot.sh
```

#### Now by adding the below line into crontab, it every hour but what exactly runs is determined within the file. By default Snapshots run every 3 hours, Blocks every 12 hours and State History every 24 hours:

```
0 * * * * /root/data/snapshots/ore-take-snapshot.sh
```

***

# ORE-Restore-Snapshot

#### This script will restore and resync your chain by using the latest snapshot provided on [ore.remblock.io/snapshots](https://ore.remblock.io/snapshots).

***

#### Setup ore-restore-snapshot script using the code below:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-restore-snapshot.sh && sudo chmod u+x ore-restore-snapshot.sh && sudo ./ore-restore-snapshot.sh
```
***

# ORE-Claim-Rewards

#### This script is capable of automating your day-to-day reward claiming.

***

## Step 1: Create Telegram Bot Using Botfather

#### The following steps describe how to create a new bot:

* Contact [**@BotFather**](https://telegram.me/BotFather) in your Telegram messenger.
* To get a token, send BotFather a message that says **`/newbot`**.
* When asked for a name for your new bot choose something that ends with the word bot, so for example my_test_bot.
* If your chosen name is available, BotFather will then send you a token.
* Save this token as you will be asked for it once you execute the script.

Once your bot is created, you can set a custom name, profile photo and description for it. The description is basically a message that explains what the bot can do.

#### To set the Bot name in BotFather do the following:

* Send **`/setname`** to BotFather.
* Select the bot which you want to change.
* Send the new name to BotFather.

#### To set a Profile photo for your bot in BotFather do the following:

* Send **`/setuserpic`** to BotFather.
* Select the bot that you want the profile photo changed on.
* Send the photo to BotFather.

#### To set Description for your bot in BotFather do the following:

* Send **`/setdescription`** to BotFather.
* Select the bot for which you are writing a description.
* Change the description and send it to BotFather.

There are some other useful methods in BotFather which we won't cover in this tutorial like **`/setcommands`**.

***

## Step 2: Obtain Your Chat Idenification Number

Theres two ways to retrieve your Chat ID, the first is by opening the following URL in your web-browser: 

[**https://api.telegram.org/botTOKEN/getUpdates**](https://api.telegram.org/botTOKEN/getUpdates) then replace the **`TOKEN`** with your actual bot token.

Your Chat ID will be shown in this format **`"id":7041782343`**, based on this example your Chat ID would of been **`7041782343`**. The second way that this can be done is through a third party telegram bot called [**@get_id_bot**](https://telegram.me/get_id_bot).

***

## Step 3: Download & Install ORE-Claim-Rewards Script:

```
sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-claim-rewards.sh && sudo chmod u+x ore-claim-rewards.sh && sudo ./ore-claim-rewards.sh
```

#### Check if ore-claim-rewards script has an upcoming "at" scheduled:

```
atq
```

#### How to setup the "at" schedule if theres no upcoming schedule, can take up to 2 minutes to complete:

```
sudo ./ore-claim-rewards.sh --at
```

#### How to remove an upcoming "at" schedule:

```
atrm <at schedule number>
```

#### Please Note: You will need to change the default key permissions:

```
nano remblock/claim/config
```
