'*****************************************************************
'**  Media Browser Roku Client - Video Screen
'*****************************************************************


'**********************************************************
'** Show Video Screen
'**********************************************************

Function showVideoScreen(episode As Object, PlayStart As Dynamic)

    if validateParam(episode, "roAssociativeArray", "showVideoScreen") = false return -1

    m.progress = 0 'buffering progress
    m.position = 0 'playback position (in seconds)
    m.runtime  = episode.Length 'runtime (in seconds)

    m.playbackPosition    = 0 ' (in seconds)
    m.paused   = false 'is the video currently paused?
    m.moreinfo = false 'more information about video

    port = CreateObject("roMessagePort")

    m.canvas = CreateObject("roImageCanvas")
    m.canvas.SetMessagePort(port)
    m.canvas.SetLayer(0, { Color: "#000000" })
    m.canvas.Show()

    m.player = CreateObject("roVideoPlayer")
    m.player.SetMessagePort(port)
    m.player.SetPositionNotificationPeriod(1)
    m.player.SetDestinationRect(0,0,0,0)
    m.player.AddContent(episode.StreamData)
    m.player.Play()

    m.canvas.AllowUpdates(false)
    PaintFullscreenCanvas()
    m.canvas.AllowUpdates(true)

    ' PlayStart in seconds
    PlayStartSeconds = Int((PlayStart / 10000) / 1000)

    ' Remote key id's for navigation
    remoteKeyUp    = 2
    remoteKeyDown  = 3
    remoteKeyLeft  = 4
    remoteKeyRight = 5
    remoteKeyOK    = 6
    remoteKeySkBk  = 7
    remoteKeyRev   = 8
    remoteKeyFwd   = 9
    remoteKeyStar  = 10
    remoteKeyPause = 13

    while true
        msg = wait(0, port)

        If type(msg) = "roVideoPlayerEvent" Then

            If msg.isFullResult() Then
                Print "full result"
                PostPlayback(episode.Id, "stop", DoubleToString(nowPosition))
                exit while

            Else If msg.isPartialResult() Then
                Print "partial result"
                PostPlayback(episode.Id, "stop", DoubleToString(nowPosition))
                exit while

            Else If msg.isRequestFailed() Then
                print "Video request failure: "; msg.GetIndex(); " " msg.GetData()
                exit While
                
            Else If msg.isScreenClosed() Then
                print "Screen closed"
                exit while

            Else If msg.isStreamStarted() Then
                Print "--- started stream ---"
                PostPlayback(episode.Id, "start")

            Else If msg.isStatusMessage() and msg.GetMessage() = "startup progress"
                paused = false
                progress% = msg.GetIndex() / 10
                If m.progress <> progress%
                    m.progress = progress%
                    PaintFullscreenCanvas()
                End If

            Else If msg.isPlaybackPosition() Then
                nowPositionSec = msg.GetIndex() + PlayStartSeconds
                nowPositionMs# = msg.GetIndex() * 1000
                nowPositionTicks# = nowPositionMs# * 10000
                nowPosition = nowPositionTicks# + PlayStart

                m.position = msg.GetIndex() + PlayStartSeconds

                PaintFullscreenCanvas()

                'Print "Time: "; FormatTime(nowPositionSec) + " / " + FormatTime(episode.Length)
                'Print "Seconds: "; nowPositionSec
                'Print "MS: "; nowPositionMs#
                'Print "Ticks: "; nowPositionTicks#
                'Print "Position:"; nowPosition

                ' Only Post Playback every 10 seconds
                If msg.GetIndex() Mod 10 = 0
                    PostPlayback(episode.Id, "progress", DoubleToString(nowPosition))
                End If

            Else If msg.isPaused() Then
                Print "Paused Position: "; nowPositionSec

                m.paused = true
                m.moreinfo = false ' Hide more info on pause

                PaintFullscreenCanvas()

            Else If msg.isResumed() Then
                Print "Resume Position: "; nowPositionSec

                m.paused = false
                PaintFullscreenCanvas()

            'Else If msg.isStatusMessage() Then
            '    print "Video status: "; msg.GetIndex(); " " msg.GetData()
            '    print "Video message: "; msg.GetMessage();

            End If

        Else If type(msg) = "roImageCanvasEvent" Then

            If msg.isRemoteKeyPressed()
                index = msg.GetIndex()

                If index = remoteKeyUp Then
                    PostPlayback(episode.Id, "stop", DoubleToString(nowPosition))
                    exit while

                Else If index = remoteKeyDown Then
                    If m.moreinfo Then
                        m.moreinfo = false
                    Else
                        m.moreinfo = true
                    End If
                    PaintFullscreenCanvas()
                    
                Else If index = remoteKeyLeft or index = remoteKeyRev Then
                    'm.position = m.position - 60
                    'm.player.Seek(m.position * 1000)

                Else If index = remoteKeyRight or index = remoteKeyFwd Then
                    'm.position = m.position + 60
                    'm.player.Seek(m.position * 1000)

                Else If index = remoteKeyPause Then
                    if m.paused m.player.Resume() else m.player.Pause()

                End if

            End If

        End If
        
        'Output events for debug
        'print msg.GetType(); ","; msg.GetIndex(); ": "; msg.GetMessage()
        'if msg.GetInfo() <> invalid print msg.GetInfo();

    end while

    m.player.Stop()
    m.canvas.Close()

    return true
End Function


'**********************************************************
'** Post Playback to Server
'**********************************************************

Function PostPlayback(videoId As String, action As String, position=invalid) As Boolean

    If action = "start"
        request = CreateURLTransferObject(GetServerBaseUrl() + "/Users/" + m.curUserProfile.Id + "/PlayingItems/" + videoId, true)
    Else If action = "progress"
        request = CreateURLTransferObject(GetServerBaseUrl() + "/Users/" + m.curUserProfile.Id + "/PlayingItems/" + videoId + "/Progress?PositionTicks=" + position, true)
    Else If action = "stop"
        request = CreateURLTransferObject(GetServerBaseUrl() + "/Users/" + m.curUserProfile.Id + "/PlayingItems/" + videoId + "?PositionTicks=" + position, true)
        request.SetRequest("DELETE")
    End If
    
    if (request.AsyncPostFromString(""))
        while (true)
            msg = wait(0, request.GetPort())

            if (type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                If (code = 200)
                    Return true
                End if
            else if (event = invalid)
                request.AsyncCancel()
                exit while
            endif
        end while
    endif

    return false
End Function


'**********************************************************
'** Paint Canvas
'**********************************************************

Sub PaintFullscreenCanvas()
    list = []
    progress_bar = invalid

    If m.progress < 100
        color = "#000000" 'opaque black
        list.Push({
            Text: "Loading..." + m.progress.tostr() + "%"
            TargetRect: { x:0, y:0, w:0, h:0 }
        })

    Else If m.paused
        color = "#80000000" 'semi-transparent black
        list.Push({
            Text: "Paused"
            TargetRect: { x:0, y:0, w:0, h:0 }
        })

        progress_bar = BuildProgressBar()

    Else If m.moreinfo
        color = "#00000000" 'fully transparent
        progress_bar = BuildProgressBar()

    Else
        color = "#00000000" 'fully transparent
        m.canvas.ClearLayer(2) 'hide progress bar
    End If

    m.canvas.SetLayer(0, { Color: color, CompositionMode: "Source" })
    m.canvas.SetLayer(1, list)

    ' Only Show Progress Bar If Paused
    If progress_bar<>invalid Then
        m.canvas.SetLayer(2, progress_bar)
    End If
End Sub


'**********************************************************
'** Build Progress Bar for Canvas
'**********************************************************

Function BuildProgressBar() As Object
    progress_bar = []

    mode = CreateObject("roDeviceInfo").GetDisplayMode()

    If mode = "720p"
        If m.position < 10
            barWidth = 1
        Else
            barWidth = Int((m.position / m.runtime) * 600)
        End If
        
        'overlay       = {TargetRect: {x: 250, y: 600, w: 800, h: 150}, Color: "#80000000" }
        barBackground = {TargetRect: {x: 350, y: 650, w: 600, h: 18}, url: "pkg:/images/progressbar/background.png"}
        barPosition   = {TargetRect: {x: 351, y: 651, w: barWidth, h: 16}, url: "pkg:/images/progressbar/bar.png"}

        'progress_bar.Push(overlay)
        progress_bar.Push(barBackground)
        progress_bar.Push(barPosition)

        ' Current Progress
        progress_bar.Push({
            Text: FormatTime(m.position)
            TextAttrs: { font: "small", color: "#FFFFFF" }
            TargetRect: { x: 250, y: 642, w: 100, h: 37 }
        })

        ' Run Time
        progress_bar.Push({
            Text: FormatTime(m.runtime)
            TextAttrs: { font: "small", color: "#FFFFFF" }
            TargetRect: { x: 952, y: 642, w: 100, h: 37 }
        })
    Else

    End If

    return progress_bar
End Function