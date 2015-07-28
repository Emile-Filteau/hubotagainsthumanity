# Description:
#   Hubot Script to play Cards Against Humanity with Slack
#
# TODO :Add help commands here
module.exports = (robot) ->

  GAME_CHANNEL = process.env.HAH_GAME_CHANNEL
  SERVER_ADDRESS = process.env.HAH_SERVER_ADDRESS
  SECRET = process.env.HAH_SECRET

  END_GAME_TIMEOUT = null

  robot.hear /^hah help$/i, (res) ->
    return if not is_in_good_channel(res)
    res.send "Welcome to Slack Against Humanity\n" +
             "Here is a list of available commands\n" +
             "hah join  : Join the game\n" +
             "hah leave : Leave the game\n" +
             "hah show cards : Send you the list of cards in your hands\n" +
             "hah start : Start a new game\n" +
             "hah stop  : Stop the current game\n" +
             "hah show  : Show current game infos\n" +
             "hah play <id> : Play card from your hand at position <id>\n" +
             "hah vote <id> : Vote for played card at position <id>\n" +
             "hah add white card <card_text> : Add a white card to the deck\n" +
             "hah add black card <card_text> : Add a black card to the deck\n" +
             "hah show deck : Send all the custom cards in private message\n" +
             "hah remove card <card_id> : Remove the desired card from the deck\n"

  robot.hear /^hah join$/i, (res) ->
    return if not is_in_good_channel(res)
    join_game(res)

  robot.hear /^hah leave$/i, (res) ->
    return if not is_in_good_channel(res)
    user = res.message.user
    create_request("/game/players/#{user.id}").delete() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      res.send 'You left the game'
    
  robot.hear /^hah show cards$/i, (res) ->
    return if not is_in_good_channel(res)
    show_player_hand(res)

  robot.hear /^hah start$/i, (res) ->
    return if not is_in_good_channel(res)
    start_game res, () ->
      f = () -> end_game(res)
      END_GAME_TIMEOUT = setTimeout(f, 60000)

  robot.hear /^hah show$/i, (res) ->
    return if not is_in_good_channel(res)
    show_game_infos(res)
      
  robot.hear /^hah stop$/i, (res) ->
    return if not is_in_good_channel(res)
    create_request('/game').delete() (err, resp, body) ->
      response = JSON.parse(body) 
      return res.send response.message if response.status?
      res.send 'Game has ended successfuly'

  robot.hear /^hah play( (\d+))$/i, (res) ->
    return if not is_in_good_channel(res)
    card_index = res.match[2]
    user = res.message.user
    data = JSON.stringify({played_card: card_index})
    create_request("/game/players/#{user.id}").put(data) (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      if response.turn_ready
        clearTimeout(END_GAME_TIMEOUT)
        end_game(res)
      res.send "#{user.name} played a card"

  robot.hear /^hah show vote$/i, (res) ->
    return if not is_in_good_channel(res)
    show_votes(res)

  robot.hear /^hah vote( (\d+))$/i, (res) ->
    return if not is_in_good_channel(res)
    card_index = res.match[2]
    user = res.message.user
    data = JSON.stringify({card: card_index, player: user.id})
    create_request("/game/vote").post(data) (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      player = null
      for _player in response.players
        if response.voted_player == _player.id
          player = _player
      res.send "#{get_player_tag(player.id)} won the round with ... He now have a score of #{player.score }\n"
      show_game_infos res, () ->
        for player in response.players
          message = response.active_card
          message += 'Here is your hand : \n'
          message += "(#{player.cards.indexOf(card)}) : #{card}\n" for card in player.cards
          user = robot.brain.data.users[player.id]
          send_private_message user, message

        f = () -> end_game(res)
        END_GAME_TIMEOUT = setTimeout(f, 60000)

  robot.hear /^hah show scores$/i, (res) ->
    return if not is_in_good_channel(res)
    show_scores(res)

  robot.hear /^hah add black card (.+?)$/i, (res) ->
    return if not is_in_good_channel(res)
    data = JSON.stringify({
        'type': 'black',
        'text': res.match[1]
    })
    create_request('/cards').post(data) (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      res.send 'Your black card have been added to the deck'

  robot.hear /^hah add white card (.+?)$/i, (res) ->
    return if not is_in_good_channel(res)
    data = JSON.stringify({
        'type': 'white',
        'text': res.match[1]
    })
    create_request('/cards').post(data) (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      res.send 'Your white card have been added to the deck'

  robot.hear /^hah show deck$/i, (res) ->
    return if not is_in_good_channel(res)
    create_request('/cards').get() (err, resp, body) ->
      response = JSON.parse(body)
      message = ''
      for card in response
        message += "(#{card.id}) #{card.type} : #{card.text}\n"
      send_private_message res.message.user, message

  robot.hear /^hah remove card( (\d+))$/i, (res) ->
    return if not is_in_good_channel(res)
    create_request("/cards/#{res.match[2]}").delete() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      res.send 'Card deleted successfully'

  join_game = (res, callback) ->
    user = res.message.user
    data = JSON.stringify({id: user.id})
    create_request('/game/players').post(data) (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      res.send "#{user.name} joined the game"
      show_player_hand(res)
      callback() if callback?
 
  show_player_hand = (res, callback) ->
    user = res.message.user
    create_request('/game/players/' + user.id).get() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      message = 'Here is your hand : \n'
      message += "(#{response.cards.indexOf(card)}) : #{card}\n" for card in response.cards
      send_private_message user, message
      callback() if callback?
  
  start_game = (res, callback) ->
    create_request('/game').post() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      if not response.active_player
        join_game res, () ->
          show_game_infos(res)
      else
        show_game_infos(res)
      callback() if callback?

  show_game_infos = (res, callback) ->
    create_request('/game').get() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      message = "Current turn  : #{response.turn+1}\n" +
                "Voting player : #{get_player_tag(response.active_player)}\n" +
                "Current card  : #{response.active_card}\n"
      res.send message
      callback() if callback?

  show_scores = (res, callback) ->
    create_request('/game').get() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      player_scores = []
      for player in response.players
        player_scores.push {id: player.id, score: player.score}
      player_scores.sort (a, b) ->
        return -1 if a.score > b.score
        return  1 if a.score < b.score
        return 0
      message = "Here is the scoreboard\n"
      for player in player_scores
        message += "#{get_player_tag(player.id)} : #{player.score}\n"
      res.send message
      callback() if callback?

  show_votes = (res, callback) ->
    create_request('/game/vote').get() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      message = "#{response.active_card}\n"
      for card in response.played_cards
        message += "(#{response.played_cards.indexOf(card)}) : #{card}\n"
      res.send message
      callback() if callback?

  end_game = (res, callback) ->
    create_request('/game/vote').get() (err, resp, body) ->
      response = JSON.parse(body)
      return res.send response.message if response.status?
      player_name = robot.brain.data.users[response.active_player].name
      message = get_player_tag(response.active_player)
      message += " it's time to vote!\n"
      message += "#{response.active_card}\n"
      for card in response.played_cards
        message += "(#{response.played_cards.indexOf(card)}) : #{card}\n"
      
      res.send message
      callback() if callback?
  
  is_in_good_channel = (res) ->
    if res.message.room != GAME_CHANNEL
      res.send "Wrong channel, please join \##{GAME_CHANNEL} to play"
      return false
    return true

  send_private_message = (user,  message) ->
    robot.send {room: user.name}, message

  get_player_tag = (player_id) ->
    player_name = robot.brain.data.users[player_id].name
    return "<@#{player_id}|#{player_name}>" 

  create_request = (action) ->
    return robot.http(SERVER_ADDRESS + action)
      .header('Content-Type', 'application/json')
      .header('X-Secret-Token', SECRET)

