# fb-scraper

**fb-scraper** is a script to scrape all of someone else’s statuses on Facebook. This cannot be done via the API, so it uses PhantomJS and CasperJS to run a headless browser, go to someone's profile page, and keeps scrolling down infinitely until the profile was created; then it gets all the text statuses and converts them to a JSON file looking like this:

```json
[
	{
		"content":"Text update",
		"permalink":"/user/posts/1234567890",
		"time":"18 February at 15:08",
		"timestamp":1424272112,
		"likes": 9,
		"shares": 0,
		"comments": 0,
		"isFriendPost":false
	},
	...
]
```

It only gets text statuses and posts received to the wall, but you could easily modify it to get other types of posts, and keep more metadata fields. There is also a script to batch insert this JSON into a MySQL database.

If you would like to archive your own profile then you're probably better off using Facebook’s [Download My Information](https://www.facebook.com/help/131112897028467) as this will be much more structured and complete than this.

## Ethical considerations

Is this tool ethical? Depends how you use it. It’s certainly against Facebook's terms of service, and **you should not archive someone's profile without their explicit, informed consent**. Essentially you should only use this if you're doing research on social networks that specifically requires this data.

**It is your responsibility to take appropriate steps to keep the resulting data safe**, such as strong file encryption, in order to protect the participants’ privacy; and delete raw data when it's not needed anymore. Where possible, you should also anonymise the data early on, by renaming your files and removing the `permalink` field, but remember that the content of updates and metadata may still contain personally identifiable information. See [“But the data is already public”](http://link.springer.com/article/10.1007/s10676-010-9227-5) (Zimmer, 2010) and [“I Didn’t Sign Up for This!”](https://research-repository.st-andrews.ac.uk/bitstream/handle/10023/6691/hutton_consent.pdf) (Hutton and Henderson, 2015) to learn more about the dangers of data leaks in SNS studies.

I assume no responsibility for improper or unethical use of this tool.

# Setup

## Installation

Requires [node.js](https://nodejs.org/) and npm.

* Clone the repository: `git clone https://github.com/victorloux/fb-scraper.git`
* Install [PhantomJS](http://phantomjs.org/download.html), and make sure it is in your `$PATH`
* From the fb-scraper folder, run `npm install` to install the dependencies

The scripts are written and annotated in CoffeeScript, but JS transpilations are provided for convenience (and because PhantomJS 2 does not directly read CoffeeScript anymore). If you would like to edit the scripts I recommend you install CoffeeScript instead of editing the JS files directly.

## Authentication

Set your shell’s environment variables `$fb_user` and `$fb_pass` to the Facebook username/password you'd normally use to log in. The easiest and safer way to do it is to duplicate the file **.env.example**, rename it to **.env**, and then edit this file with your username/email and password. Once this is done you'll need to run `source .env` in your shell.

# Usage
## Get someone's statuses

```
casperjs --config=conf.json scrape.js USERNAME
```

Where USERNAME is either a profile ID, or the username that comes after the / in their URL. If _username_ is omitted then it will steal Mark Zuckerberg’s profile by default. Take that, Zuck.

## Modifying the parsing script

Once you have scraped a profile, and want to edit the code to change how a raw HTML status is parsed into JSON, you can add `--parse-only` which will use the cached version of the scraped profile (ending with .raw) to generate a new JSON file, instead of trying to re-download the whole thing every time which is quite long.

The code needs to be refactored to a cleaner state but should still be readable. Give me a shout if you really don't understand anything.

Also, remember to compile your CoffeeScript before running CasperJS, or you'll run the older JS file. A watch script is useful.

## Push into a database

Setup a MySQL table with the following fields (adjust as needed if you created new fields):

```sql
CREATE TABLE `statuses` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(255) DEFAULT NULL,
  `content` text,
  `permalink` varchar(255) DEFAULT NULL,
  `timestamp` bigint(20) DEFAULT NULL,
  `likes` int(11) DEFAULT NULL,
  `shares` int(11) DEFAULT NULL,
  `comments` int(11) DEFAULT NULL,
  `is_friend_post` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
);
```

Edit **save-to-db.coffee** and **.env** with your database credentials. Then run:

```
coffee save-to-db.js USERNAME
```

# To do

The script has some (many) bugs, and lacks tests, graceful error handling, configuration, and better sanitisation of the statuses to a usable format. It's all quite hard to do reliably because it's a headless browser, and unexpected changes in the page are harder to detect, but it will be fixed someday. In the meantime, PRs welcome if that project is particularly useful to you.

Also there's an awful “fix” somewhere which causes profiles with over 150 pages to not be downloaded in full. If it's a blocker for you adjust the code as needed, it's an arbitrary number because some profiles never show a Born event and so the script never stops. Until I find an actual fix.
