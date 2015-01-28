module.exports = (Main)->
  Instance = null
  Provider =
    exclusive: true
    selector: '.source.php,.source.cpp'
    blacklist: '.comment'
    requestHandler:(options)->
      AutoComplete.suggestions(options.buffer,options.editor)
  class AutoComplete
    @points = ['"',"'",' ',')','(',',','{','}',':','-','+','>','<',';',"\n","\r"]
    @activate:->
      return if Main.Status.AutoComplete
      Instance = atom.services.provide('autocomplete.provider', '1.0.0', {provider:Provider})
      Main.Status.AutoComplete = true
    @deactivate:->
      return unless Main.Status.AutoComplete+
      Instance.dispose()
      Main.Status.AutoComplete = false
    @suggestions:(buffer,editor)->
      path = editor.getPath()
      text = buffer.getText()
      index = buffer.characterIndexForPosition(editor.getCursorBufferPosition())
      text = text.substr(0,index)+'AUTO332'+text.substr(index)
      prefix = @prefix(text,index)
      return new Promise (resolve)->
        Main.V.H.exec(['--auto-complete'],text,path).then (result)->
          toReturn = []
          result = result.stdout.split("\n").filter((e)-> e)
          if result.length
            result.forEach (entry)->
              entry = entry.split(' ')
              if entry[0].substr(0,1) is ':'
                toReturn.push {word:entry[0].replace(':',''),label:entry.join(' '),prefix:prefix}
              else
                toReturn.push {word:entry[0],label:entry.slice(1).join(' '),prefix:prefix}
          resolve toReturn
    @prefix:(text,index)->
      LaText = []
      while((index = index-1))
        char = text.substr(index,1)
        if @points.indexOf(char) isnt -1
          break
        LaText.push char
      return LaText.reverse().join('').trim()