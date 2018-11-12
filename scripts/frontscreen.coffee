
module.exports = (robot) ->
  robot.hear //i, (res) ->
    if not process.env.HUBOT_DISPLAY_CHANNEL
      return
    if not process.env.HUBOT_DISPLAY_ADDRESS
      return
    room = robot.adapter.client.rtm.dataStore.getChannelGroupOrDMById res.message.room
    if not room.is_channel
      return
    console.log(room.name)
    if room.name != process.env.HUBOT_DISPLAY_CHANNEL
      return
    user = res.message.user.name
    console.log(user)
    message = res.message.text
    console.log(message)
    data = JSON.stringify({
      name: user,
      chat: message
    })
    robot.http("http://"+process.env.HUBOT_DISPLAY_ADDRESS+"/chat")
      .post(data) (err, response, body) ->
        console.log err
        console.log response
  robot.respond /Change welcome message to (.+) for (\d+) (seconds|minutes|hours)/i, (res) ->
    if not robot.auth.hasRole msg.message.user, "frontscreen"
      robot.send "Only frontscreen admins can change the frontscreen"
      return
    console.log(res.match)
    multiplyer = if res.match[3] == "seconds" then 1 else if res.match[3] == "minutes" then 60 else if res.match[3] == "hours" then 60*60 else 1
    data = JSON.stringify({
      text: res.match[1],
      timeout: res.match[2]*multiplyer
    })
    console.log 'timeout', res.match[2]*multiplyer
    robot.http("http://"+process.env.HUBOT_DISPLAY_ADDRESS+"/welcome")
      .post(data) (err, response,body) ->
        console.log err
        console.log response
  robot.respond /Clear the welcome message/i, (res) ->
    if not robot.auth.hasRole msg.message.user, "frontscreen"
      robot.send "Only frontscreen admins can change the frontscreen"
      return
    data = JSON.stringify({
      text: "",
      timeout: 0
    })
    console.log 'cleared front screen'
    robot.http("http://"+process.env.HUBOT_DISPLAY_ADDRESS+"/welcome")
      .post(data) (err, response,body) ->
        console.log err
        console.log response

  robot.on 'doorUnlock', (unlock) ->
    user = unlock.user
    name = user.real_name
    data = JSON.stringify({
      text: name,
      timeout: 15
    })
    robot.http("http://"+process.env.HUBOT_DISPLAY_ADDRESS+"/welcome")
      .post(data) (err, response,body) ->
        console.log err
        console.log response
