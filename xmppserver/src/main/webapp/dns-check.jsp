<%--
  -
  - Copyright (C) 2016-2024 Ignite Realtime Foundation. All rights reserved.
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
<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page errorPage="error.jsp"%>

<%@ page import="java.util.*"%>
<%@ page import="org.jivesoftware.openfire.net.DNSUtil" %>
<%@ page import="org.jivesoftware.openfire.XMPPServer" %>
<%@ page import="org.jivesoftware.openfire.spi.ConnectionConfiguration" %>
<%@ page import="org.jivesoftware.openfire.spi.ConnectionType" %>
<%@ page import="org.jivesoftware.openfire.ConnectionManager" %>
<%@ page import="org.jivesoftware.openfire.net.SrvRecord" %>
<%@ page import="java.util.stream.Collectors" %>
<%@ page import="java.util.stream.Stream" %>
<%@ page import="java.net.InetAddress" %>
<%@ page import="java.net.Inet4Address" %>
<%@ page import="java.net.UnknownHostException" %>
<%@ page import="java.net.Inet6Address" %>

<%@ taglib uri="admin" prefix="admin" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/functions" prefix="fn" %>

<jsp:useBean id="webManager" class="org.jivesoftware.util.WebManager" />
<% webManager.init(request, response, session, application, out ); %>

<%
    final String xmppDomain = XMPPServer.getInstance().getServerInfo().getXMPPDomain();
    final String hostname = XMPPServer.getInstance().getServerInfo().getHostname();
    final List<SrvRecord> dnsSrvRecordsClient = DNSUtil.srvLookup( "xmpp-client", "tcp", xmppDomain );
    final List<SrvRecord> dnsSrvRecordsServer = DNSUtil.srvLookup( "xmpp-server", "tcp", xmppDomain );
    final List<SrvRecord> dnsSrvRecordsClientTLS = DNSUtil.srvLookup( "xmpps-client", "tcp", xmppDomain );
    final List<SrvRecord> dnsSrvRecordsServerTLS = DNSUtil.srvLookup( "xmpps-server", "tcp", xmppDomain );

    // Check if A and AAAA records exist for each discovered hostname.
    final Set<String> unknownHosts = new HashSet<>();
    final Set<String> hostnames = Stream.of(dnsSrvRecordsClient, dnsSrvRecordsClientTLS, dnsSrvRecordsServer, dnsSrvRecordsServerTLS)
        .flatMap(Collection::stream)
        .map(SrvRecord::getHostname).collect(Collectors.toSet());
    final Set<String> ipv4Capable = hostnames.stream().filter(host -> {
        try {
            for (InetAddress i : InetAddress.getAllByName(host)) {
                if (i instanceof Inet4Address) {
                    return true;
                }
            }
        } catch (UnknownHostException e) {
            unknownHosts.add(host);
        }
        return false;
    }).collect(Collectors.toSet());

    final Set<String> ipv6Capable = hostnames.stream().filter(host -> {
        try {
            for (InetAddress i : InetAddress.getAllByName(host)) {
                if (i instanceof Inet6Address) {
                    return true;
                }
            }
        } catch (UnknownHostException e) {
            unknownHosts.add(host);
        }
        return false;
    }).collect(Collectors.toSet());

    boolean detectedRecordForHostname = false;
    for ( final SrvRecord dnsSrvRecord : dnsSrvRecordsClient )
    {
        if ( hostname.equalsIgnoreCase( dnsSrvRecord.getHostname() ) )
        {
            detectedRecordForHostname = true;
            break;
        }
    }

    for ( final SrvRecord dnsSrvRecord : dnsSrvRecordsServer )
    {
        if ( hostname.equalsIgnoreCase( dnsSrvRecord.getHostname() ) )
        {
            detectedRecordForHostname = true;
            break;
        }
    }

    final ConnectionManager manager = XMPPServer.getInstance().getConnectionManager();

    final ConnectionConfiguration plaintextClientConfiguration = manager.getListener( ConnectionType.SOCKET_C2S, false ).generateConnectionConfiguration();
    final ConnectionConfiguration directtlsClientConfiguration = manager.getListener( ConnectionType.SOCKET_C2S, true  ).generateConnectionConfiguration();
    final ConnectionConfiguration plaintextServerConfiguration = manager.getListener( ConnectionType.SOCKET_S2S, false ).generateConnectionConfiguration();
    final ConnectionConfiguration directtlsServerConfiguration = manager.getListener( ConnectionType.SOCKET_S2S, true  ).generateConnectionConfiguration();

    pageContext.setAttribute( "xmppDomain", xmppDomain );
    pageContext.setAttribute( "hostname", hostname );
    pageContext.setAttribute( "dnsSrvRecordsClient", dnsSrvRecordsClient );
    pageContext.setAttribute( "dnsSrvRecordsServer", dnsSrvRecordsServer );
    pageContext.setAttribute( "dnsSrvRecordsClientTLS", dnsSrvRecordsClientTLS );
    pageContext.setAttribute( "dnsSrvRecordsServerTLS", dnsSrvRecordsServerTLS );
    pageContext.setAttribute( "ipv4Capable", ipv4Capable );
    pageContext.setAttribute( "ipv6Capable", ipv6Capable );
    pageContext.setAttribute( "unknownHosts", unknownHosts );
    pageContext.setAttribute( "detectedRecordForHostname", detectedRecordForHostname );
    pageContext.setAttribute( "plaintextClientConfiguration", plaintextClientConfiguration );
    pageContext.setAttribute( "directtlsClientConfiguration", directtlsClientConfiguration );
    pageContext.setAttribute( "plaintextServerConfiguration", plaintextServerConfiguration );
    pageContext.setAttribute( "directtlsServerConfiguration", directtlsServerConfiguration );
%>

<html>
<head>
    <title><fmt:message key="system.dns.srv.check.title"/></title>
    <meta name="pageID" content="server-settings"/>
</head>
<body>

<c:choose>
    <c:when test="${detectedRecordForHostname}">
        <admin:infobox type="info">
            <fmt:message key="system.dns.srv.check.detected_matching_records.one-liner" />
        </admin:infobox>
        <fmt:message key="system.dns.srv.check.detected_matching_records.description" var="plaintextboxcontent"/>
    </c:when>
    <c:when test="${xmppDomain eq hostname}">
        <admin:infobox type="info">
            <fmt:message key="system.dns.srv.check.xmppdomain_equals_hostname.one-liner" />
        </admin:infobox>
        <fmt:message key="system.dns.srv.check.xmppdomain_equals_hostname.description" var="plaintextboxcontent"/>
    </c:when>
    <c:when test="${empty dnsSrvRecordsServer and empty dnsSrvRecordsClient and empty dnsSrvRecordsClientTLS and empty dnsSrvRecordsServerTLS}">
        <admin:infobox type="warning">
            <fmt:message key="system.dns.srv.check.no-records.one-liner" />
        </admin:infobox>
        <fmt:message key="system.dns.srv.check.no-records.description" var="plaintextboxcontent"/>
    </c:when>
    <c:otherwise>
        <admin:infobox type="warning">
            <fmt:message key="system.dns.srv.check.no-match.one-liner" />
        </admin:infobox>
        <fmt:message key="system.dns.srv.check.no-match.description" var="plaintextboxcontent"/>
    </c:otherwise>
</c:choose>

<c:if test="${not empty unknownHosts}">
    <admin:infobox type="warning">
        <fmt:message key="system.dns.srv.check.unknown-hosts.one-liner" />
    </admin:infobox>
</c:if>

<p>
    <fmt:message key="system.dns.srv.check.info">
        <fmt:param value="${xmppDomain}" />
        <fmt:param value="${hostname}" />
        <fmt:param value="<a href=\"server-props.jsp\">" />
        <fmt:param value="</a>"/>
    </fmt:message>
</p>

<fmt:message key="system.dns.srv.check.name" var="plaintextboxtitle"/>
<admin:contentBox title="${plaintextboxtitle}">
    <c:out value="${plaintextboxcontent}"/>

    <c:if test="${not empty unknownHosts}">
        <p><fmt:message key="system.dns.srv.check.unknown-hosts.description" /></p>
        <ul style="margin-top: 1em">
            <c:forEach items="${unknownHosts}" var="unknownHost">
                <li><tt><c:out value="${unknownHost}"/></tt></li>
            </c:forEach>
        </ul>
    </c:if>
</admin:contentBox>

<c:if test="${not empty dnsSrvRecordsClient or not empty dnsSrvRecordsServer or not empty dnsSrvRecordsClientTLS or not empty dnsSrvRecordsServerTLS}">

    <fmt:message key="system.dns.srv.check.recordbox.title" var="plaintextboxtitle"/>
    <admin:contentBox title="${plaintextboxtitle}">

        <p><fmt:message key="system.dns.srv.check.recordbox.description"/></p>

        <c:if test="${not empty dnsSrvRecordsClient}">
            <c:set var="resulttableTitle"><fmt:message key="system.dns.srv.check.label.client-host" /></c:set>
            <c:set var="dnsSrvRecords" value="${dnsSrvRecordsClient}"/>
            <%@ include file="dns-check-resulttable.jspf" %>
        </c:if>

        <c:if test="${not empty dnsSrvRecordsClientTLS}">
            <c:set var="resulttableTitle"><fmt:message key="system.dns.srv.check.label.client-host-tls" /></c:set>
            <c:set var="dnsSrvRecords" value="${dnsSrvRecordsClientTLS}"/>
            <%@ include file="dns-check-resulttable.jspf" %>
        </c:if>

        <c:if test="${not empty dnsSrvRecordsServer}">
            <c:set var="resulttableTitle"><fmt:message key="system.dns.srv.check.label.server-host" /></c:set>
            <c:set var="dnsSrvRecords" value="${dnsSrvRecordsServer}"/>
            <%@ include file="dns-check-resulttable.jspf" %>
        </c:if>

        <c:if test="${not empty dnsSrvRecordsServerTLS}">
            <c:set var="resulttableTitle"><fmt:message key="system.dns.srv.check.label.server-host-tls" /></c:set>
            <c:set var="dnsSrvRecords" value="${dnsSrvRecordsServerTLS}"/>
            <%@ include file="dns-check-resulttable.jspf" %>
        </c:if>
    </admin:contentBox>
</c:if>

<br/>

<p>
    <fmt:message key="system.dns.srv.check.rationale" />
</p>
<p>
    <fmt:message key="system.dns.srv.check.example" />
</p>
<ul>
    <c:if test="${plaintextClientConfiguration.enabled}">
        <li><code>_xmpp-client._tcp.<c:out value="${xmppDomain}"/>. 86400 IN SRV 0 5 ${plaintextClientConfiguration.port} <c:out value="${hostname}"/>.</code></li>
    </c:if>
    <c:if test="${directtlsClientConfiguration.enabled}">
        <li><code>_xmpps-client._tcp.<c:out value="${xmppDomain}"/>. 86400 IN SRV 0 5 ${directtlsClientConfiguration.port} <c:out value="${hostname}"/>.</code></li>
    </c:if>
    <c:if test="${plaintextServerConfiguration.enabled}">
        <li><code>_xmpp-server._tcp.<c:out value="${xmppDomain}"/>. 86400 IN SRV 0 5 ${plaintextServerConfiguration.port} <c:out value="${hostname}"/>.</code></li>
    </c:if>
    <c:if test="${directtlsServerConfiguration.enabled}">
        <li><code>_xmpps-server._tcp.<c:out value="${xmppDomain}"/>. 86400 IN SRV 0 5 ${directtlsServerConfiguration.port} <c:out value="${hostname}"/>.</code></li>
    </c:if>
</ul>
<p>
    <fmt:message key="system.dns.srv.check.disclaimer" />
</p>

</body>
</html>
