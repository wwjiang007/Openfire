<%@ page contentType="text/html; charset=UTF-8" %>
<%--
  -
  - Copyright (C) 2004-2008 Jive Software, 2017-2025 Ignite Realtime Foundation. All rights reserved.
  -
  - Licensed under the Apache License, Version 2.0 (the "License");
  - you may not use this file except in compliance with the License.
  - You may obtain a copy of the License at
  -
  -     http://www.apache.org/licenses/LICENSE-2.0
  -
  - Unless required by applicable law or agreed to in writing, software
  - distributed under the License is distributed on an "AS IS" BASIS,
  - WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  - See the License for the specific language governing permissions and
  - limitations under the License.
--%>

<%@ page import="org.jivesoftware.openfire.muc.MUCOccupant,
                 org.jivesoftware.openfire.muc.MUCRoom,
                 org.jivesoftware.util.ParamUtils,
                 org.jivesoftware.util.StringUtils,
                 org.jivesoftware.util.CookieUtils,
                 org.jivesoftware.util.JiveGlobals,
                 java.net.URLEncoder,
                 java.text.DateFormat"
    errorPage="error.jsp"
%>
<%@ page import="org.jivesoftware.openfire.XMPPServer" %>
<%@ page import="org.jivesoftware.openfire.muc.NotAllowedException" %>
<%@ page import="org.xmpp.packet.JID" %>
<%@ page import="java.util.List" %>
<%@ page import="org.jivesoftware.openfire.muc.MUCOccupant" %>
<%@ page import="java.nio.charset.StandardCharsets" %>

<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<%@ taglib prefix="admin" uri="admin" %>
<jsp:useBean id="webManager" class="org.jivesoftware.util.WebManager" />
<% webManager.init(request, response, session, application, out); %>

<%  // Get parameters
    JID roomJID = new JID(ParamUtils.getParameter(request,"roomJID"));
    String nickName = ParamUtils.getParameter(request,"nickName");
    String kick = ParamUtils.getParameter(request,"kick");
    String roomName = roomJID.getNode();
    Cookie csrfCookie = CookieUtils.getCookie(request, "csrf");
    String csrfParam = ParamUtils.getParameter(request, "csrf");

    if (kick != null) {
        if (csrfCookie == null || csrfParam == null || !csrfCookie.getValue().equals(csrfParam)) {
            kick = null;
        }
    }
    csrfParam = StringUtils.randomString(15);
    CookieUtils.setCookie(request, response, "csrf", csrfParam, -1);
    pageContext.setAttribute("csrf", csrfParam);

    // Load the room object
    MUCRoom room = webManager.getMultiUserChatManager().getMultiUserChatService(roomJID).getChatRoom(roomName);
    if (room == null) {
        // The requested room name does not exist so return to the list of the existing rooms
        response.sendRedirect("muc-room-summary.jsp?roomJID="+URLEncoder.encode(roomJID.toBareJID(), StandardCharsets.UTF_8));
        return;
    }

    // Kick nick specified
    if (kick != null) {
        String consoleKickReason = JiveGlobals.getProperty("admin.mucRoom.consoleKickReason", null);
        List<MUCOccupant> occupants = room.getOccupantsByNickname(nickName);
        if (occupants != null && !occupants.isEmpty()) {
            for (MUCOccupant occupant : occupants) {
                room.kickOccupant(occupant.getUserAddress(), room.getSelfRepresentation().getAffiliation(), room.getSelfRepresentation().getRole(), XMPPServer.getInstance().createJID(webManager.getUser().getUsername(), null), null, consoleKickReason);
            }
            webManager.getMultiUserChatManager().getMultiUserChatService(roomJID).syncChatRoom(room);

            // Log the event
            webManager.logEvent("kicked MUC occupant "+nickName+" from "+roomName, null);
            // Done, so redirect
            response.sendRedirect("muc-room-occupants.jsp?roomJID="+URLEncoder.encode(room.getJID().toBareJID(), StandardCharsets.UTF_8)+"&nickName="+URLEncoder.encode(nickName, StandardCharsets.UTF_8)+"&deletesuccess=true");
            return;
        }
    }

    // Formatter for dates
    DateFormat dateFormatter = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT);

    pageContext.setAttribute("nickName", nickName);
%>

<html>
<head>
<title><fmt:message key="muc.room.occupants.title"/></title>
<meta name="subPageID" content="muc-room-occupants"/>
<meta name="extraParams" content="<%= "roomJID="+URLEncoder.encode(roomJID.toBareJID(), StandardCharsets.UTF_8)+"&create=false" %>"/>
</head>
<body>

    <p>
    <fmt:message key="muc.room.occupants.info" />
    </p>

    <%  if (request.getParameter("deletesuccess") != null) { %>

    <admin:infobox type="success">
        <fmt:message key="muc.room.occupants.kicked">
            <fmt:param><c:out value="${nickName}"/></fmt:param>
        </fmt:message>
    </admin:infobox>

    <%  } %>

    <%  if (request.getParameter("deletefailed") != null) { %>

    <admin:infobox type="eerror">
        <fmt:message key="muc.room.occupants.kickfailed">
            <fmt:param><c:out value="${nickName}"/></fmt:param>
        </fmt:message>
    </admin:infobox>

    <%  } %>

    <div class="jive-table">
    <table>
    <thead>
        <tr>
            <th scope="col"><fmt:message key="muc.room.edit.form.room_id" /></th>
            <th scope="col"><fmt:message key="muc.room.edit.form.users" /></th>
            <th scope="col"><fmt:message key="muc.room.edit.form.on" /></th>
            <th scope="col"><fmt:message key="muc.room.edit.form.modified" /></th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td><%= StringUtils.escapeHTMLTags(room.getName()) %></td>
            <td><%= room.getOccupantsCount() %> / <%= room.getMaxUsers() %></td>
            <td><%= dateFormatter.format(room.getCreationDate()) %></td>
            <td><%= dateFormatter.format(room.getModificationDate()) %></td>
        </tr>
    </tbody>
    </table>
    </div>

    <br>
    <p>
        <fmt:message key="muc.room.occupants.detail.info" />
    </p>

    <div class="jive-table">
    <table>
    <thead>
        <tr>
            <th scope="col"><fmt:message key="muc.room.occupants.user" /></th>
            <th scope="col"><fmt:message key="muc.room.occupants.nickname" /></th>
            <th scope="col"><fmt:message key="muc.room.occupants.role" /></th>
            <th scope="col"><fmt:message key="muc.room.occupants.affiliation" /></th>
            <th scope="col"><fmt:message key="muc.room.occupants.kick" /></th>
        </tr>
    </thead>
    <tbody>
        <% for (MUCOccupant occupant : room.getOccupants()) { %>
        <tr>
            <td><%= StringUtils.escapeHTMLTags(occupant.getUserAddress().toString()) %></td>
            <td><%= StringUtils.escapeHTMLTags(occupant.getNickname()) %></td>
            <td><%= StringUtils.escapeHTMLTags(occupant.getRole().toString()) %></td>
            <td><%= StringUtils.escapeHTMLTags(occupant.getAffiliation().toString()) %></td>
            <td><a href="muc-room-occupants.jsp?roomJID=<%= URLEncoder.encode(room.getJID().toBareJID(), StandardCharsets.UTF_8) %>&nickName=<%= URLEncoder.encode(occupant.getNickname(), StandardCharsets.UTF_8) %>&kick=1&csrf=${csrf}" title="<fmt:message key="muc.room.occupants.kick"/>"><img src="images/delete-16x16.gif" alt="<fmt:message key="muc.room.occupants.kick"/>" /></a></td>
        </tr>
        <% } %>
    </tbody>
    </table>
    </div>

    </body>
</html>
