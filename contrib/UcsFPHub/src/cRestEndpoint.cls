VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "cRestEndpoint"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'=========================================================================
'
' UcsFPHub (c) 2019 by Unicontsoft
'
' Unicontsoft Fiscal Printers Hub
'
' This project is licensed under the terms of the MIT license
' See the LICENSE file in the project root for more information
'
'=========================================================================
Option Explicit
DefObj A-Z
Private Const MODULE_NAME As String = "cRestEndpoint"

'=========================================================================
' Constants and member variables
'=========================================================================

Private Const DEF_LISTEN_PORT           As Long = 8192
Private Const STR_SOCKET_LISTEN         As String = "����� �� %1 ���� %2"
Private Const STR_CONN_ESTABLISHED      As String = "������ %1 ���������� (%2 ����)"
Private Const STR_CONN_RECEIVE          As String = "������ %1 ������� ������"
Private Const STR_CONN_ERROR            As String = "������ ��� ������ %1: %2"

Private m_oConfig                   As Object
Private m_oPrinters                 As Object
Private WithEvents m_oSocket        As cAsyncSocket
Attribute m_oSocket.VB_VarHelpID = -1
Private m_cClients                  As Collection
Private m_lCount                    As Long

'=========================================================================
' Error handling
'=========================================================================

Private Sub PrintError(sFunction As String)
    Debug.Print "Critical error: " & Err.Description & " [" & MODULE_NAME & "." & sFunction & "]"
End Sub

'=========================================================================
' Properties
'=========================================================================

Property Get Printers() As Object
    Set Printers = m_oPrinters
End Property

'=========================================================================
' Methods
'=========================================================================

Public Function Init(oConfig As Object, oPrinters As Object) As Boolean
    Const FUNC_NAME     As String = "Init"
    Dim vSplit          As Variant
    Dim lListenPort     As Long
    
    On Error GoTo EH
    Set m_oConfig = oConfig
    Set m_oPrinters = oPrinters
    vSplit = Split(C_Str(JsonItem(oConfig, "Address")), ":")
    lListenPort = Znl(C_Lng(At(vSplit, 1)), DEF_LISTEN_PORT)
    Set m_oSocket = New cAsyncSocket
    If Not m_oSocket.Create(SocketPort:=lListenPort, SocketAddress:=At(vSplit, 0)) Then
        GoTo QH
    End If
    If Not m_oSocket.Listen() Then
        GoTo QH
    End If
    ConsolePrint STR_SOCKET_LISTEN & " (" & MODULE_NAME & ")" & vbCrLf, Zn(At(vSplit, 0), "127.0.0.1"), lListenPort
    '--- success
    Init = True
QH:
    Exit Function
EH:
    PrintError FUNC_NAME
    Resume Next
End Function

Public Function ClientReceive(sKey As String) As Boolean
    Const FUNC_NAME     As String = "frClientReceive"
    Dim oClient         As cRestClient
    Dim sBody           As String
    
    On Error GoTo EH
    If SearchCollection(m_cClients, sKey, RetVal:=oClient) Then
        ConsolePrint STR_CONN_RECEIVE & " (" & MODULE_NAME & ")" & vbCrLf, sKey
        ConsolePrint "Route=" & oClient.HttpMethod & " " & oClient.RawUrl & vbCrLf
        ConsolePrint "Headers=" & JsonDump(oClient.Headers) & vbCrLf
        ConsolePrint "Body=" & oClient.Body & vbCrLf
        sBody = "<html><body>" & vbCrLf & _
            "<p>" & oClient.HttpMethod & " " & oClient.RawUrl & "</p>" & vbCrLf & _
            "<p>" & Replace(JsonDump(oClient.Headers), vbCrLf, "<br>" & vbCrLf) & "</p>" & vbCrLf & _
            "<p>" & Replace(oClient.Body, vbCrLf, "<br>" & vbCrLf) & "</p>" & vbCrLf & _
            "</body></html>"
        oClient.Socket.SendText "HTTP/1.1 200" & vbCrLf & _
            "Content-Type: text/html" & vbCrLf & _
            "Content-Length: " & Len(sBody) & vbCrLf & vbCrLf & _
            sBody, CodePage:=ucsScpAcp
        '--- success
        ClientReceive = True
    End If
    Exit Function
EH:
    PrintError FUNC_NAME
    Resume Next
End Function

Public Sub ClientClose(sKey As String)
    If SearchCollection(m_cClients, sKey) Then
        m_cClients.Remove sKey
    End If
End Sub

Public Sub ClientError(sKey As String)
    Const FUNC_NAME     As String = "frClientError"
    Dim oClient         As cRestClient
    
    On Error GoTo EH
    If SearchCollection(m_cClients, sKey, RetVal:=oClient) Then
        ConsoleColorError FOREGROUND_RED, FOREGROUND_MASK, STR_CONN_ERROR & " (" & MODULE_NAME & ")" & vbCrLf, sKey, oClient.LastError
    End If
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Private Function pvThreadPoolGetRestClient() As cRestClient
    '--- ToDo: impl multi-threading
    Set pvThreadPoolGetRestClient = New cRestClient
End Function

'=========================================================================
' Events
'=========================================================================

Private Sub m_oSocket_OnAccept()
    Const FUNC_NAME     As String = "m_oSocket_OnAccept"
    Dim sKey            As String
    Dim oClient         As cRestClient
    
    On Error GoTo EH
    m_lCount = m_lCount + 1
    sKey = "#" & m_lCount
    Set oClient = pvThreadPoolGetRestClient()
    If oClient Is Nothing Then
        GoTo QH
    End If
    If Not oClient.Init(sKey, m_oSocket, Me) Then
        GoTo QH
    End If
    m_cClients.Add oClient, sKey
    ConsolePrint STR_CONN_ESTABLISHED & " (" & MODULE_NAME & ")" & vbCrLf, sKey, m_cClients.Count
QH:
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

'=========================================================================
' Base class events
'=========================================================================

Private Sub Class_Initialize()
    Set m_cClients = New Collection
End Sub

Private Sub Class_Terminate()
    Set m_cClients = Nothing
End Sub