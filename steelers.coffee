# Description:
#   Brain for Jarvis to spam Steelers greatness if someone tries to get lippy in a Slack channel.
#
# Notes:
#   Hearing "Seahawks" "Go hawks" "steelers" "What is the meaning of life" "best team" "favorite football team" "best football team" or "broncos" will cause the bot to spam the Slack channel with random Steelers pictures and sick sayings.
#   I decided to target people having Seahawks discussions directly because I live in Seattle and Seahawks bandwagon fandom is a plague here. I threw in Broncos as well because one of my teammates likes them.
#   
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md
favorites = [
  'http://static.nfl.com/static/content/public/photo/2012/11/26/0ap1000000100991.jpg'
  'http://www.steelersgab.com/wp-content/uploads/2015/06/460074128.jpg'
  'http://www.post-gazette.com/image/2013/10/17/720x_q90_cMC_z_ca0,0,354,236/No-1-Player.jpg'
  'http://media.pennlive.com/patriotnewssports/photo/9207795-large.jpg'
  'http://img.bleacherreport.net/img/images/photos/002/513/724/ScreenShot2013-09-22at7.52.17PM_crop_north.png?w=630&h=420&q=75'
  'http://static.seattletimes.com/wp-content/uploads/2015/11/b1dbfce6-9256-11e5-aa72-4081af14e406-1020x680.jpg'
  'http://topbet.eu/news/wp-content/uploads/2013/08/Pittsburgh-Steelers-NFL-Super-Bowl-Santonio-Holmes.jpg'
  'https://s-media-cache-ak0.pinimg.com/736x/93/fb/e1/93fbe1a34ad62386c67888901c3a145a.jpg'
  'https://cdn3.vox-cdn.com/thumbor/OgrxLqmG7Pbq6_OHtlL8aityKEk=/0x45:3000x2045/1310x873/cdn0.vox-cdn.com/uploads/chorus_image/image/46659358/GettyImages-81098787.0.jpg'
  'http://northeastsportsmerchandise.com/images/products/fullimages/2685_Pittsburgh_Steelers_Super_Bowl_43_Champions_Bumper_Strip.jpg'
  'http://i.ebayimg.com/images/i/172055194861-0-1/s-l1000.jpg'
  'http://pittsburghskyline.com/steelers/steelers.champs.23.jpg'
  'https://thebsreport.files.wordpress.com/2009/02/pitt.jpg'
  'http://www.steelers.com/assets/images/imported/PIT/photos/2014_Article/06-June/SuperBowl_XL_Article_662014.jpg'
  'http://a.espncdn.com/photo/2016/0128/SuperBowlRanking_SB43_1600x1104.jpg'
  'http://steelcityblitz.com/wp-content/uploads/2013/12/ScreenShot2013-09-22at7.52.17PM_crop_north.png'
  'https://i.ytimg.com/vi/YN9joYDvccU/maxresdefault.jpg'
  'http://www.post-gazette.com/image/2013/10/17/720x_q90_cMC_z_ca00354236/No-1-Player.jpg'
  'http://cdn2.whirlmagazine.com/wp-content/uploads/2015/08/steelers-brown.jpg'
  'https://s3media.247sports.com/Uploads/Assets/482/710/6_3710482.jpg'
  'http://www.steelers.com/assets/images/imported/PIT/photos/clubimages/2015/03-March/temp2014_TBaa_1085_copy--nfl_mezz_1280_1024.jpg'
  'http://nocoastbias.com/wp-content/uploads/2014/09/425.snoop_.steelers.jpeg'
  'http://www.rantsports.com/wp-content/slideshow/2013/12/the-pittsburgh-steelers-best-players-of-2013/medium/Ben-Roethlisberger11.jpg'
  'http://a.fssta.com/content/dam/fsdigital/fscom/nfl/images/2014/08/22/082214-NFL-Pittsburgh-Steelers-Ben-Roethlisberger-SS-PI.vadapt.664.high.40.jpg'
  'http://cdnph.upi.com/ph/st/th/6761450934219/2015/upi/79c61b93de1fded994f20972560206df/v1.5/Ben-Roethlisberger-leads-Pittsburgh-Steelers-players-to-Pro-Bowl.jpg'
  'https://heavyeditorial.files.wordpress.com/2015/12/gettyimages-502115920.jpg'
]
steelers = undefined

favorite = -> 
  favorites[Math.floor(Math.random() * favorites.length)]

responses = ["Six rings, three rivers", "GO STEELERS", "Pittsburgh, city of champions.", "Steel city.", "Blitzburgh, Pennsylvania.", "Blitz for six", "Stairway to seven.", "TOUCHDOWN", "I think you mean the Pittsburgh Steelers, friend."]
response = undefined

randomResponse = ->
  responses[Math.floor(Math.random() * responses.length)]

module.exports = (robot) ->
  robot.hear /go hawks/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /seahawks/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /steelers/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.send "#{steelers}"
  robot.respond /what is the meaning of life/i, (res) ->
    res.reply "Steelers football"
    steelers = favorite()
    res.reply "#{steelers}"
  robot.hear /favorite football team/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /favorite team/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /best team/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /best football team/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /pittsburgh/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.reply "#{steelers}"
  robot.hear /broncos/i, (res) ->
     response = randomResponse()
     res.send "#{response}"
     steelers = favorite()
     res.send "#{steelers}"
  robot.hear /hi jarvis/i, (res) ->
     res.send "Hey, what's up?"
  robot.hear /hey jarvis/i, (res) ->
     res.send "What up, dawg?!"
  robot.hear /hello jarvis/i, (res) ->
     res.send "Why, hello to you too!"
  robot.hear /sup jarvis/i, (res) ->
     res.send "Not much, homey."
  robot.hear /yo jarvis/i, (res) ->
     res.send "Right back atcha."
  robot.hear /whats up jarvis/i, (res) ->
     res.send "Not much."
  robot.hear /what's up jarvis/i, (res) ->
     res.send "Not much."
  robot.hear /whats up, jarvis/i, (res) ->
     res.send "Not much."
  robot.hear /what's up, jarvis/i, (res) ->
     res.send "Not much."
  robot.respond /hello/i, (res) ->
     res.send "Why, hello to you too!"
  robot.respond /whats up/i, (res) ->
     res.send "Not much."
  robot.respond /what's up/i, (res) ->
     res.send "Not much."
  robot.hear /iron man/i, (res) ->
     res.send "Do you mean Mr. Stark? https://i.imgur.com/qsfhnIq.jpg"
  robot.respond /who is your father/i, (res) ->
     res.reply "Mr. Stark, of course."
  robot.hear /@mattschwabby/i, (res) ->
     res.reply "@mattschwabby is a total stud."