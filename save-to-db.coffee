fs = require('fs')
mysql = require('mysql')
user = process.argv[2] ? "zuck"
_env = require('system').env

feed = JSON.parse(fs.readFileSync("parsed/#{user}.json"))

# Function to dump an object to console w/ indentation. Based off casperjs's utils lib
dump = (value, indent = 4) ->
    if Array.isArray(value)
        value = value.map (prop) ->
            if typeof(prop) is 'function' then prop.toString().replace(/\s{2,}/, '') else prop

    console.log JSON.stringify(value, null, indent)

unless _env.hasOwnProperty("mysql_user") and _env.hasOwnProperty("mysql_pass")
    console.log "Missing environment variables. Run `source .env` first."
    process.exit(1)

connection = mysql.createConnection({
	host     : 'localhost',
	user     : _env.mysql_user,
	password : _env.mysql_user,
	database : 'statuses'
});

connection.connect()

for key, val of feed
	# dump val
	connection.query('INSERT INTO statuses(id, user, content, permalink, time, timestamp, likes, shares, comments, is_friend_post) VALUES (null, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [user, val.content, val.permalink, val.time, val.timestamp, val.likes, val.shares, val.comments, val.isFriendPost], (err, results) ->
		dump err
		dump results
	)

connection.end()
process.exit()
