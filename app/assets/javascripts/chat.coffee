###
Created with JetBrains WebStorm.
User: Joe
Date: 6/22/12
Time: 4:50 PM
###

# Imports
TextHolder = exports.TextHolder
DoubleList = exports.DoubleList
CircleMap  = exports.CircleMap

THROTTLE_DELAY = 100

# Variables into which to cache jQuery selector results
$globals =
  $inputBuffer: undefined
  $usersOnline: undefined
  $chatLog:     undefined
  $container:   undefined
  $copier:      undefined
  $textCopier:  undefined
  $agentType:   undefined
  $outputState: undefined
  $onError:     undefined
  $onErrorSpan: undefined
  $onChat:      undefined

# Other globals
globals =
  userName:      undefined
  socket:        undefined
  messageCount:  0
  messageList:   new DoubleList(20)
  agentTypeList: new CircleMap()
  logList:       []

exports.$chatGlobals = $globals
exports.chatGlobals  = globals

# Onload
document.body.onload = ->

  initSelectors()
  initAgentList()

  globals.userName = extractParamFromURL("username")
  $globals.$agentType.text(globals.agentTypeList.getCurrent())
  throttledSend = throttle(send, THROTTLE_DELAY)

  WS = if window['MozWebSocket'] then MozWebSocket else WebSocket
  globals.socket = new WS(socketURL)

  updateUserList = (users) ->
    $globals.$usersOnline.text("")
    for user in users
      row =
        """
        <tr><td>
          <input id='#{user}' value='#{user}' type='button'
          onclick='exports.event.copySetup(this.value)'
          style='border:none; background-color: #FFFFFF; width: 100%; text-align: left'>
        </td></tr>
        """
      $globals.$usersOnline.append(row)

  globals.socket.onmessage = (event) ->

    data = JSON.parse(event.data)
    decideShowErrorOrChat(data)

    d       = new Date()
    time    = d.toTimeString()[0..4]
    user    = data.user
    context = data.context
    message = data.message
    kind    = data.kind  # //@ I'm currently ignoring this... (maybe act on kinds; maybe do something special for messages from self)

    globals.logList[globals.messageCount] = new TextHolder(message)
    difference = $globals.$container[0].scrollHeight - $globals.$container.scrollTop()
    $globals.$chatLog.append(messageSwitcher(user, context, message, time))
    if difference is $globals.$container.innerHeight() or user is globals.userName then textScroll()

    updateUserList(data.members)

  keyString =
      'abcdefghijklmnopqrstuvwxyz' +
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
      '1234567890!@#$%^&*()' +
      '\<>-_=+[{]};:",.?\\|\'`~'
  keyArray = keyString.split('')

  AgentTypeCount = 5
  agentTypeNumArr = [1..AgentTypeCount]

  numMorpher = (modifier) -> (num) -> modifier + "+shift+" + num
  ctrlArr    = agentTypeNumArr[0..].map(numMorpher("ctrl"))
  cmdArr     = agentTypeNumArr[0..].map(numMorpher("command"))

  Mousetrap.bind('tab', (e) ->
    e.preventDefault()
    globals.agentTypeList.next()
    setAgentType()
  , 'keydown')

  Mousetrap.bind(keyArray, (-> focusInput()), 'keydown')

  Mousetrap.bind('enter', (e) -> input = $globals.$inputBuffer.val(); throttledSend(input) if e.target.id is 'inputBuffer' and /\S/g.test(input))

  Mousetrap.bind(['up', 'down'], (e) ->
    if e.target.id is 'inputBuffer'
      charCode = extractCharCode(e)
      e.preventDefault()
      scroll(charCode)
  )

  Mousetrap.bind('space', (e) ->
    if e.target.id is 'container' or e.target.id is 'copier'
      e.preventDefault()
      textScroll()
      focusInput()
  )

  Mousetrap.bind(['ctrl+c', 'command+c'], (e) ->
    # If there are only digit characters in e.target.id...
    # This would mean that e.target is a table row in the chat output.
    if e.target.id is 'container' or (/[\d]+/).test(e.target.id)
      $globals.$textCopier.show()  # Show, so we can select the text for copying
      $globals.$textCopier.focus()
      $globals.$textCopier.select()
      setTimeout((-> $globals.$textCopier.hide(); focusInput()), 50)
  , 'keydown')

  Mousetrap.bind(ctrlArr.concat(cmdArr), (e) ->
    num = extractCharCode(e) - 48  # This will get us keyboard number pressed (1/2/3/4/5)
    e.preventDefault()
    setAgentTypeIndex(num - 1)
  )

  Mousetrap.bind('pageup', (-> $globals.$container.focus()))


###
Basic page functionality
###

# Caching jQuery selector results for easy access throughout the code
# Return Type: Unit
initSelectors = ->
  $globals.$inputBuffer = $("#inputBuffer")
  $globals.$usersOnline = $("#usersOnline")
  $globals.$chatLog     = $("#chatLog")
  $globals.$container   = $("#container")
  $globals.$copier      = $("#copier")
  $globals.$textCopier  = $("#textCopier")
  $globals.$agentType   = $("#agentType")
  $globals.$outputState = $("#outputState")
  $globals.$onError     = $("#onError")
  $globals.$onErrorSpan = $("#onError span")
  $globals.$onChat      = $("#onChat")

# Return Type: Unit
initAgentList = ->
  agentTypes = ['observer', 'turtles', 'patches', 'links', 'chatter']
  agentTypes.map((type) -> globals.agentTypeList.append(type))

# Return Type: Unit
decideShowErrorOrChat = (data) ->
  if data.error
    globals.socket.close()
    $globals.$onErrorSpan.text(data.error)
    $globals.$onError.show()
  else
    $globals.$onChat.show()

# Return Type: String
messageSwitcher = (user, context, final_text, time) ->

  globals.messageCount++
  colorClass =
    if user is globals.userName
      "self_user_colored"
    else if globals.agentTypeList.contains(user)
      "channel_context_colored"
    else
      "other_user_colored"

  """
    <div class='chat_message background_colored'>
      <table>
        <tr>
          <td class='user #{colorClass}'>#{user}</td>
          <td class='context contrast_colored'>@#{context}</td>
          <td class='message common_text_colored'>#{final_text}</td>
          <td class='timestamp contrast_colored'>#{time}</td>
        </tr>
    </div>
  """

# Return Type: Unit
extractParamFromURL = (paramName) ->
  params = window.location.search.substring(1) # `substring` to drop the '?' off of the beginning
  params.match(///(?:&[^&]*)*#{paramName}=([^&]*).*///)[1]

#  """
#  <tr style='vertical-align: middle; outline: none; width: 100%; border-collapse: collapse;' onmouseup='exports.event.handleTextRowOnMouseUp(this)' tabindex='1' id='#{globals.state-1}'>
#  </tr>
#  """

# Return Type: Unit
textScroll = ->
  bottom = $globals.$container[0].scrollHeight - $globals.$container.height()
  font = $globals.$container.css('font-size')
  size = parseInt(font.substr(0, font.length - 2))
  $globals.$container.scrollTop(bottom - size)
  $globals.$container.animate({'scrollTop': bottom}, 'fast')

# Credit to Remy Sharp.
# http://remysharp.com/2010/07/21/throttling-function-calls/
# Return Type: () => Unit
throttle = (fn, delay) ->
  timer = null
  ->
    [context, args] = [this, arguments]
    clearTimeout(timer)
    timer = setTimeout((-> fn.apply(context, args)), delay)

# Return Type: Int or Event (//@ Yikes!)
extractCharCode = (e) ->
  if e && e.which
    e.which
  else if window.event
    window.event.which
  else
    e  # Should pretty much never happen

# Return Type: Unit
setAgentTypeIndex = (index) ->
  globals.agentTypeList.setCurrentIndex(index)
  $globals.$agentType.text(globals.agentTypeList.getCurrent())

# Return Type: Unit
setAgentType = ->
  $globals.$agentType.text(globals.agentTypeList.getCurrent())

# Return Type: Unit
scroll = (key) ->

  ml = globals.messageList

  if key is 38  # Up arrow
    if ml.cursor
      ml.cursor = if ml.cursor.prev != null then ml.cursor.prev else ml.cursor
    else
      ml.addCurrent($globals.$inputBuffer.val(), globals.agentTypeList.getCurrent())
      ml.cursor = ml.head
  else if key is 40  # Down arrow
    ml.cursor = ml.cursor.next

  extractInfoAndType = (source) -> [source.data, source.type]

  [info, type] =
    if ml.cursor
      extractInfoAndType(ml.cursor)
    else
      [info, type] = extractInfoAndType(ml.current)
      ml.clearCursor()
      [info, type]

  globals.agentTypeList.setCurrent(type)
  setAgentType()
  $globals.$inputBuffer.val(info)

# Return Type: Unit
send = (message) ->
  globals.socket.send(JSON.stringify({ agentType: $globals.$agentType.text(), cmd: message }))
  globals.messageList.append(message, globals.agentTypeList.getCurrent())
  globals.messageList.clearCursor()
  $globals.$inputBuffer.val("")
  focusInput()

# Return Type: Unit
focusInput = -> $globals.$inputBuffer.focus()