# fb-scraper
#
# IMPORTANT: run casperjs with --ignore-ssl-errors=yes --cookies-file=cookies.txt


_env = require("system").env
fs = require("fs")
casper = require("casper").create({
    # verbose: true,  # useful for debug
    logLevel: "debug",
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/537.22 (KHTML, like Gecko) Chrome/25.0.1364.172 Safari/537.22",
    pageSettings: {  # Save resources (set to true if you'd like to take screenshots)
      loadImages:  false,
      loadPlugins: false
    }
})

cheerio = require("cheerio")  # Library to parse HTML with a jQuery-like API

# Check that credentials exist
unless _env.hasOwnProperty("fb_user") and _env.hasOwnProperty("fb_pass")
    casper.echo "Missing environment variables. Do `source .env` first."
    casper.exit()

# Define the user to fetch
user = if casper.cli.has(0) then casper.cli.get(0) else "zuck"
filePath = "parsed/#{user}.json"
skipScraping = casper.cli.has("parse-only")

# @todo: --parse-only is implemented in a very hacky, last-minute way
# and should be just a big if-else with better separated functions,
# at the moment it runs Casper for nothing.
# Also the 'parser' of posts should be a class/single function.


###*
 * This transforms elements of a single post into a JSON object
 * @param  {object} item    The current status item
 * @return {object}
###
parseFacebookPost = (item) ->
    ###*
     * Count number of shares on a post
     * @param  {Cheerio} el The full status element
     * @return {int}    Number of shares
    ###
    countShares = (el) ->
        return 0 if el('.UFIShareLink').length is 0
        return parseInt(el('.UFIShareLink').first().text().match(/[0-9]+/), 10)

    ###*
     * Count number of likes on a post
     * @param  {Cheerio} el The full status element
     * @return {int}    Number of likes
    ###
    countLikes = (el) ->
        return 0 if el('._1g5v').length is 0
        return parseInt(el('._1g5v').text().match(/[0-9]+/), 10)

    ###*
     * Count number of comments on a post
     * NOTE: at the moment this doesn't count comment replies on purpose
     * if you do want to count them... exercise left to the reader!
     *
     * @param  {Cheerio} el The full status element
     * @return {int}    Number of comments
    ###
    countComments = (el) ->
        total = 0
        total += el('span.UFICommentBody').length  # comment blocks
        unless el('.UFIPagerRow').length is 0  # comment pager ("show 12 more comments")
            total += parseInt(el('.UFIPagerRow').first().text().match(/[0-9]+/), 10)
        return total


    if !item.html then return null

    $ = cheerio.load(item.html)

    # Determine whether the post contains a link/photo, and if it has any textual content
    # If yes, just skip it (this can be modified if you want to keep it)
    if $('.userContent').first().text() == "" or $('.mtm').length > 0
        return null

    return {
        content:    $('.userContent').first().text()
        permalink:  $('abbr').first().parents('a').attr('href')
        time:       $('abbr').first().text()
        timestamp:  $('abbr').first().data('utime')
        likes:      countLikes($)
        shares:     countShares($)
        comments:   countComments($)
        isFriendPost: $('.mhs').length > 0
    }

# Let's try to authenticate first
casper.start "https://www.facebook.com", ->
    if skipScraping then return
    pageTitle = @getTitle()

    # note: you may have to change this if your locale isn't English
    if pageTitle is "Facebook - Log In or Sign Up"
        casper.echo "Attempting to log in..."

        query =
            email: _env.fb_user
            pass: _env.fb_pass
        @fill "#login_form", query, true

    # Because we keep cookies, you might remain logged in from PhantomJS
    else if pageTitle is "Facebook"
        casper.echo "Already logged in"

    else
        casper.echo "Oops, something unexpected happened. Page title: #{pageTitle}"
        casper.exit()

    # else if @getTitle() is "Redirecting..."
        # casper.echo "Logged in"

# Once we're logged in, we move on to the profile
casper.thenOpen "https://www.facebook.com/#{ user }"
currentPage = 1
hasClickedAllStories = false

casper.then ->
    if skipScraping then return
    casper.echo "Now on https://www.facebook.com/#{ user }"
    casper.echo @getTitle()

    # Recursive function that keeps scrolling down
    tryAndScroll = ->
        casper.waitFor ->
            casper.scrollToBottom()
            true
        , ->
            unless hasClickedAllStories
                # Click on Visible Highlights to show all stories
                if casper.visible '#u_jsonp_6_4'
                    casper.click '#u_jsonp_6_4'
                    casper.echo '[clicked Visible Highlights]'

                    hasClickedAllStories = true

            # When we see the "Born" block, then we'll stop. Until then keep scrolling!
            # @todo: sometimes it never shows and the script keeps chugging along merrily on inexistent pages. The current terrible fix is to stop it regardless at 150 pages but it should just check if there's nothing new that was added.
            unless currentPage > 150 or casper.visible { type: "xpath", path: "//a[@class and starts-with(.,'Born')]" }
                casper.echo "Loaded page #{ currentPage++ }"
                tryAndScroll()

    tryAndScroll()

# Once the first part has finished: we have reached the bottom of the page,
# so we take all the elements in the page, parse them & save them
casper.then ->
    casper.echo "Reached end of profile, parsing and saving to #{ filePath }"

    # take all the <div> with class .userContentWrapper on our big page
    # and store them into elements, then save that file
    if !skipScraping
        elements = @getElementsInfo '.userContentWrapper'
        fs.write(filePath + ".raw", JSON.stringify(elements))
    else  # or load it (if --parse-only)
        elements = JSON.parse(fs.read(filePath + ".raw"))

    # Then one by one we'll run our parseFacebookPost() function on every div
    # and add it to an array
    parsedPosts = []
    for key, item of elements
        if (p = parseFacebookPost(item)) isnt null
            parsedPosts.push p

    # And we write our array to a file.
    fs.write(filePath, JSON.stringify(parsedPosts), "w")
    casper.echo "Done!"

casper.run()