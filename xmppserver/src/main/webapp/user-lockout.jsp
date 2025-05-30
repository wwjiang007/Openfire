<%@ page contentType="text/html; charset=UTF-8" %>
<%--
  -
  - Copyright (C) 2005-2008 Jive Software, 2017-2025 Ignite Realtime Foundation. All rights reserved.
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

<%@ page import="org.jivesoftware.openfire.lockout.LockOutFlag"
    errorPage="error.jsp"
%>
<%@ page import="org.jivesoftware.openfire.lockout.LockOutManager" %>
<%@ page import="org.jivesoftware.openfire.security.SecurityAuditManager" %>
<%@ page import="org.jivesoftware.openfire.session.ClientSession" %>
<%@ page import="org.jivesoftware.util.ParamUtils" %>
<%@ page import="org.jivesoftware.util.StringUtils" %>
<%@ page import="org.jivesoftware.util.CookieUtils" %>
<%@ page import="org.xmpp.packet.JID" %>
<%@ page import="org.xmpp.packet.StreamError" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.nio.charset.StandardCharsets" %>

<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>

<jsp:useBean id="webManager" class="org.jivesoftware.util.WebManager" />
<% webManager.init(request, response, session, application, out ); %>

<%  // Get parameters //
    boolean cancel = request.getParameter("cancel") != null;
    boolean unlock = request.getParameter("unlock") != null;
    boolean lock = request.getParameter("lock") != null;
    String username = ParamUtils.getParameter(request,"username");
    String usernameUrlEncoded = URLEncoder.encode(username, StandardCharsets.UTF_8);
    long startdelay = ParamUtils.getLongParameter(request,"startdelay",-1); // -1 is immediate, -2 custom
    long duration = ParamUtils.getLongParameter(request,"duration",-1); // -1 is infinite, -2 custom
    if (startdelay == -2) {
        startdelay = ParamUtils.getLongParameter(request,"startdelay_custom", -1);
    }
    if (duration == -2) {
        duration = ParamUtils.getLongParameter(request,"duration_custom", -1);
    }
    Cookie csrfCookie = CookieUtils.getCookie(request, "csrf");
    String csrfParam = ParamUtils.getParameter(request, "csrf");
    if (lock || unlock) {
        if (csrfCookie == null || csrfParam == null || !csrfCookie.getValue().equals(csrfParam)) {
            lock = false;
            unlock = false;
        }
    }
    csrfParam = StringUtils.randomString(15);
    CookieUtils.setCookie(request, response, "csrf", csrfParam, -1);
    pageContext.setAttribute("csrf", csrfParam);

    // Handle a cancel
    if (cancel) {
        response.sendRedirect("user-properties.jsp?username=" + usernameUrlEncoded);
        return;
    }

    // Handle a user lockout:
    if (lock) {
        Date startTime = null;
        if (startdelay != -1) {
            startTime = new Date(new Date().getTime() + startdelay*60000);
        }
        Date endTime = null;
        if (duration != -1) {
            if (startTime != null) {
                endTime = new Date(startTime.getTime() + duration*60000);
            }
            else {
                endTime = new Date(new Date().getTime() + duration*60000);
            }
        }
        // Lock out the user
        webManager.getLockOutManager().disableAccount(username, startTime, endTime);
        if (!SecurityAuditManager.getSecurityAuditProvider().blockUserEvents()) {
            // Log the event
            webManager.logEvent("locked out user "+username, "start time = "+startTime+", end time = "+endTime);
        }
        // Close the user's connection if the lockout is immedate
        if (webManager.getLockOutManager().isAccountDisabled(username)) {
            final StreamError error = new StreamError(StreamError.Condition.not_authorized);
            for (ClientSession sess : webManager.getSessionManager().getSessions(username) )
            {
                sess.deliverRawText(error.toXML());
                sess.close();
            }
            // Disabled your own user account, force login
            if (username.equals(webManager.getAuthToken().getUsername())){
                session.removeAttribute("jive.admin.authToken");
                response.sendRedirect("login.jsp");
                return;
            }
        }
        // Done, so redirect
        response.sendRedirect("user-properties.jsp?username=" + usernameUrlEncoded + "&locksuccess=1");
        return;
    }

    // Handle a user unlock:
    if (unlock) {
        // Unlock the user's account
        webManager.getLockOutManager().enableAccount(username);
        if (!SecurityAuditManager.getSecurityAuditProvider().blockUserEvents()) {
            // Log the event
            webManager.logEvent("unlocked user "+username, null);
        }
        // Done, so redirect
        response.sendRedirect("user-properties.jsp?username=" + usernameUrlEncoded + "&unlocksuccess=1");
        return;
    }

    pageContext.setAttribute( "usernameHtmlEscaped", StringUtils.escapeHTMLTags(JID.unescapeNode(username)) );
    pageContext.setAttribute( "usernameUrlEncoded", usernameUrlEncoded );
%>

<html>
    <head>
        <title><fmt:message key="user.lockout.title"/></title>
        <meta name="subPageID" content="user-lockout"/>
        <meta name="extraParams" content="username=${usernameUrlEncoded}"/>
    </head>
    <body>

<% if (LockOutManager.getLockOutProvider().isReadOnly()) { %>
<div class="error">
    <fmt:message key="user.read_only"/>
</div>
<% } %>

<%
    LockOutFlag flag = LockOutManager.getInstance().getDisabledStatus(username);
    if (flag != null) {
        // User is locked out
%>

<p>
<fmt:message key="user.lockout.locked">
    <fmt:param value="<b><a href=\"user-properties.jsp?username=${usernameUrlEncoded}\">${usernameHtmlEscaped}</a></b>"/>
</fmt:message>
<% if (flag.getStartTime() != null) { %><fmt:message key="user.lockout.locked2"><fmt:param value="<%= flag.getStartTime().toString() %>"/></fmt:message> <% } %>
<% if (flag.getStartTime() != null && flag.getEndTime() != null) { %> <fmt:message key="user.lockout.lockedand" /> <% } %> 
<% if (flag.getEndTime() != null) { %><fmt:message key="user.lockout.locked3"><fmt:param value="<%= flag.getEndTime().toString() %>"/></fmt:message> <% } %>
</p>

<form action="user-lockout.jsp">
    <input type="hidden" name="username" value="${usernameHtmlEscaped}">
    <input type="hidden" name="csrf" value="${csrf}">
    <input type="submit" name="unlock" value="<fmt:message key="user.lockout.unlock" />">
    <input type="submit" name="cancel" value="<fmt:message key="global.cancel" />">
</form>

<%
    }
    else {
        // User is not locked out
%>

<p>
<fmt:message key="user.lockout.info" />
<b><a href="user-properties.jsp?username=${usernameUrlEncoded}">${usernameHtmlEscaped}</a></b>
<fmt:message key="user.lockout.info1" />
</p>

<c:if test="${webManager.user.username == param.username}">
    <p class="jive-warning-text">
    <fmt:message key="user.lockout.warning" /> <b><fmt:message key="user.lockout.warning2" /></b> <fmt:message key="user.lockout.warning3" />
    </p>
</c:if>

<form action="user-lockout.jsp">
    <input type="hidden" name="csrf" value="${csrf}">
    <% if (LockOutManager.getLockOutProvider().isDelayedStartSupported()) { %>
    <b><fmt:message key="user.lockout.time.startdelay" /></b><br />
    <input type="radio" name="startdelay" id="c1" value="-1" checked="checked" /> <label for="c1"><fmt:message key="user.lockout.time.immediate" /></label><br />
    <input type="radio" name="startdelay" id="c2" value="60" /> <label for="c2"><fmt:message key="user.lockout.time.in" /> <fmt:message key="user.lockout.time.1hour" /></label><br />
    <input type="radio" name="startdelay" id="c3" value="1440" /> <label for="c3"><fmt:message key="user.lockout.time.in" /> <fmt:message key="user.lockout.time.1day" /></label><br />
    <input type="radio" name="startdelay" id="c4" value="10080" /> <label for="c4"><fmt:message key="user.lockout.time.in" /> <fmt:message key="user.lockout.time.1week" /></label><br />
    <input type="radio" name="startdelay" id="c5" value="-2" /> <label for="c5"><fmt:message key="user.lockout.time.in" /></label> <input type="text" size="5" maxlength="10" id="startdelay_custom" name="startdelay_custom" /> <label for="startdelay_custom"><fmt:message key="user.lockout.time.minutes"/></label><br />
    <br />
    <% } %>
    <% if (LockOutManager.getLockOutProvider().isTimeoutSupported()) { %>
    <b><fmt:message key="user.lockout.time.duration" /></b><br />
    <input type="radio" name="duration" id="c6" value="-1" checked="checked" /> <label for="c6"><fmt:message key="user.lockout.time.forever" /></label><br />
    <input type="radio" name="duration" id="c7" value="60" /> <label for="c7"><fmt:message key="user.lockout.time.for" /> <fmt:message key="user.lockout.time.1hour" /></label><br />
    <input type="radio" name="duration" id="c8" value="1440" /> <label for="c8"><fmt:message key="user.lockout.time.for" /> <fmt:message key="user.lockout.time.1day" /></label><br />
    <input type="radio" name="duration" id="c9" value="10080" /> <label for="c9"><fmt:message key="user.lockout.time.for" /> <fmt:message key="user.lockout.time.1week" /></label><br />
    <input type="radio" name="duration" id="c0" value="-2" /> <label for="c0"><fmt:message key="user.lockout.time.for" /></label> <input type="text" size="5" maxlength="10" id="duration_custom" name="duration_custom" /> <label for="duration_custom"><fmt:message key="user.lockout.time.minutes"/></label><br />
    <br />
    <% } %>
    <input type="hidden" name="username" value="<%= StringUtils.escapeForXML(username) %>">
    <input type="submit" name="lock" value="<fmt:message key="user.lockout.lock" />">
    <input type="submit" name="cancel" value="<fmt:message key="global.cancel" />">
</form>

<%
    }
%>

<%  // Disable the form if a read-only user provider.
    if (LockOutManager.getLockOutProvider().isReadOnly()) { %>

<script>
  function disable() {
    let limit = document.forms[0].elements.length;
    for (let i=0;i<limit;i++) {
      document.forms[0].elements[i].disabled = true;
    }
  }
  disable();
</script>
    <% } %>

    </body>
</html>
