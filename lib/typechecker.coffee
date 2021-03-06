module.exports = (Main)->
  Subscriptions = []
  Decorations = []
  Errors = []
  LeErrors = []
  Editor = atom.workspace.getActiveEditor()
  EditorView = atom.views.getView(Editor)
  ActiveFile = Editor?.getPath()
  ScrollSubscription = null
  ScrollTimeout = null
  class TypeChecker
    @activate:->
      return unless not Main.Status.TypeChecker
      Main.Status.TypeChecker = true
      if Editor
        ScrollSubscription = Editor.on 'scroll-top-changed',=>
          clearTimeout ScrollTimeout
          ScrollTimeout = setTimeout(@OnScroll.bind(this),100)
      Subscriptions.push atom.workspace.observeTextEditors (editor)=>
        Grammar = editor.getGrammar()
        return unless Grammar or Grammar.name isnt 'PHP' or Grammar.name isnt 'Hack' or Grammar.name isnt 'C++'
        editor.buffer.onDidSave (info)=>
          @Lint()
      Subscriptions.push atom.workspace.onDidChangeActivePaneItem =>
        ScrollSubscription?.dispose()
        ScrollSubscription = null

        Editor = atom.workspace.getActiveEditor()
        EditorView = atom.views.getView(Editor)
        ActiveFile = Editor?.getPath()
        if ActiveFile
          ScrollSubscription = Editor.on 'scroll-top-changed',=>
            clearTimeout ScrollTimeout
            ScrollTimeout = setTimeout(@OnScroll.bind(this),100)
          try
            @OnScroll()
          catch error
            console.error(error.stack);
    @deactivate:->
      return unless Main.Status.TypeChecker
      Main.Status.TypeChecker = false
      Subscriptions.forEach (sub)-> sub.dispose()
      Subscriptions = []
      @RemoveDecorations()
      @RemoveErrors()
      Main.V.MPI.close()
      ScrollSubscription?.dispose()
    @Lint:->
      Main.V.H.exec(['--json'],null,ActiveFile).then (result)=>
        try
          result = JSON.parse(result.stderr.substr(result.stderr.indexOf('{')))
        catch error
          console.log "Invalid JSON"
          console.log result
        Errors = result.errors
        try
          @ProcessErrors()
        catch error
          console.error(error.stack)
    @RemoveDecorations:->
      if Main.TypeCheckerDecorations.length
        Main.TypeCheckerDecorations.forEach (decoration)-> try decoration.destroy()
        Main.TypeCheckerDecorations = []
    @RemoveErrors:->
      LeErrors.forEach (error)-> error.Remove()
      LeErrors = []
    @ProcessErrors:->
      @RemoveDecorations()
      @RemoveErrors()
      return Main.V.MPI.close() unless Errors.length
      for Error,I in Errors
        LeFirst = true
        for TraceEntry in Error.message
          Color = if LeFirst then 'red' else 'blue'
          LeErrors.push new Main.V.TE(I,TraceEntry.path,TraceEntry.line,TraceEntry.start,TraceEntry.end,Color,Error.message)
          LeFirst = false
      try setTimeout @OnScroll.bind(this),70
    @OnScroll:->
      RowStart = EditorView.getFirstVisibleScreenRow()
      RowEnd = EditorView.getLastVisibleScreenRow()
      LineHeight = getComputedStyle(EditorView)['line-height'];
      Main.V.MPI.clear()
      if LeErrors.length
        Main.V.MPI.attach()
        # Set a summary
        Main.V.MPI.add(new Main.V.MP.PlainMessageView(
          raw: true
          message: ''
        ))
        # Summary part ends
        LeErrors.forEach (error)->
          error.Render(RowStart,RowEnd,ActiveFile,Editor,EditorView,LineHeight)
      else
        Main.V.MPI.close()
