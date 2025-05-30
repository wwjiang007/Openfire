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

<%@ page import="org.jivesoftware.util.*,
                 org.jivesoftware.openfire.*,
                 java.util.HashMap,
                 java.util.Map,
                 java.text.DecimalFormat"
    errorPage="error.jsp"
%>
<%@ page import="java.time.Duration" %>

<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<%@ taglib prefix="admin" uri="admin" %>


<jsp:useBean id="webManager" class="org.jivesoftware.util.WebManager"/>
<% webManager.init(request, response, session, application, out ); %>

<html>
<head>
<title><fmt:message key="offline.messages.title"/></title>
<meta name="pageID" content="server-offline-messages"/>
<meta name="helpPage" content="manage_offline_messages.html"/>
</head>
<body>

<c:set var="success" />

<%! // Global vars and methods:

    // Strategy definitions:
    static final int BOUNCE = 1;
    static final int DROP = 2;
    static final int STORE = 3;
    static final int ALWAYS_STORE = 4;
    static final int STORE_AND_BOUNCE = 5;
    static final int STORE_AND_DROP = 6;
%>

<%  // Get parameters
    OfflineMessageStrategy manager = webManager.getXMPPServer().getOfflineMessageStrategy();
    boolean update = request.getParameter("update") != null;
    int strategy = ParamUtils.getIntParameter(request,"strategy",-1);
    int storeStrategy = ParamUtils.getIntParameter(request,"storeStrategy",-1);
    double quota = ParamUtils.getDoubleParameter(request,"quota", manager.getQuota()/1024);
    DecimalFormat format = new DecimalFormat("#0.00");

    String offlinecleaner = ParamUtils.getParameter( request, "offlinecleaner" );
    String offlinechecktimer = ParamUtils.getParameter( request, "offlinechecktimer" );
    String daystolive = ParamUtils.getParameter( request, "daystolive" );

    pageContext.setAttribute( "offlinecleaner", offlinecleaner );
    pageContext.setAttribute( "offlinechecktimer", offlinechecktimer );
    pageContext.setAttribute( "daystolive", daystolive );

    // Update the session kick policy if requested
    Map<String, String> errors = new HashMap<>();
    Cookie csrfCookie = CookieUtils.getCookie(request, "csrf");
    String csrfParam = ParamUtils.getParameter(request, "csrf");

    if (update) {
        if (csrfCookie == null || csrfParam == null || !csrfCookie.getValue().equals(csrfParam)) {
            update = false;
            errors.put("csrf", "CSRF Failure!");
        }
    }
    csrfParam = StringUtils.randomString(15);
    CookieUtils.setCookie(request, response, "csrf", csrfParam, -1);
    pageContext.setAttribute("csrf", csrfParam);
    if (update) {
        // Validate params
        if (strategy != BOUNCE && strategy != DROP && strategy != STORE) {
            errors.put("general","Please choose one of the 3 strategies below.");
        }
        else {
            // Validate the storage policy of store strat is chosen:
            if (strategy == STORE) {
                if (storeStrategy != ALWAYS_STORE && storeStrategy != STORE_AND_BOUNCE
                        && storeStrategy != STORE_AND_DROP)
                {
                    errors.put("general", LocaleUtils.getLocalizedString("offline.messages.choose_policy"));
                }
                else {
                    // Validate the store size limit:
                    if (quota <= 0) {
                        errors.put("quota", LocaleUtils.getLocalizedString("offline.messages.enter_store_size"));
                    }
                }
            }
        }
        // If no errors, continue:
        if (errors.isEmpty()) {

            if (strategy == STORE) {
                manager.setType(OfflineMessageStrategy.Type.store);

                if (storeStrategy == STORE_AND_BOUNCE) {
                    manager.setType(OfflineMessageStrategy.Type.store_and_bounce);
                }
                else if (storeStrategy == STORE_AND_DROP) {
                    manager.setType(OfflineMessageStrategy.Type.store_and_drop);
                }
                else /* (storeStrategy == ALWAYS_STORE) */ {
                    manager.setType(OfflineMessageStrategy.Type.store);
                }
            }
            else {
                if (strategy == BOUNCE) {
                    manager.setType(OfflineMessageStrategy.Type.bounce);
                }
                else if (strategy == DROP) {
                    manager.setType(OfflineMessageStrategy.Type.drop);
                }
            }

            final boolean enable = offlinecleaner!=null&&offlinecleaner.equalsIgnoreCase("on");
            final Duration checkInterval = Duration.ofMinutes( offlinechecktimer!=null&&!offlinechecktimer.trim().isEmpty() ? Integer.parseInt(offlinechecktimer) : OfflineMessageStore.OFFLINE_AUTOCLEAN_CHECKINTERVAL.getDefaultValue().toMinutes() );
            final Duration daysToLive = Duration.ofDays( daystolive!=null&&!daystolive.trim().isEmpty() ? Integer.parseInt(daystolive) : OfflineMessageStore.OFFLINE_AUTOCLEAN_DAYSTOLIVE.getDefaultValue().toDays() );
            OfflineMessageStore.OFFLINE_AUTOCLEAN_ENABLE.setValue(enable);
            OfflineMessageStore.OFFLINE_AUTOCLEAN_CHECKINTERVAL.setValue(checkInterval);
            OfflineMessageStore.OFFLINE_AUTOCLEAN_DAYSTOLIVE.setValue(daysToLive);

            manager.setQuota((int)(quota*1024));

            // Log the event
            webManager.logEvent("edited offline message settings", "quota = "+quota+"\ntype = "+manager.getType());
%>
<c:set var="success" value="true" />
<%
        }
    }

    // Update variable values

    if (errors.isEmpty()) {
        if (manager.getType() == OfflineMessageStrategy.Type.store
                || manager.getType() == OfflineMessageStrategy.Type.store_and_bounce
                || manager.getType() == OfflineMessageStrategy.Type.store_and_drop)
        {
            strategy = STORE;

            if (manager.getType() == OfflineMessageStrategy.Type.store_and_bounce) {
                storeStrategy = STORE_AND_BOUNCE;
            }
            else if (manager.getType() == OfflineMessageStrategy.Type.store_and_drop) {
                storeStrategy = STORE_AND_DROP;
            }
            else /*(manager.getType() == OfflineMessageStrategy.STORE)*/ {
                storeStrategy = ALWAYS_STORE;
            }
        }
        else {
            if (manager.getType() == OfflineMessageStrategy.Type.bounce) {
                strategy = BOUNCE;
            }
            else if (manager.getType() == OfflineMessageStrategy.Type.drop) {
                strategy = DROP;
            }
        }

        quota = ((double)manager.getQuota()) / (1024);
        if (quota < 0) {
            quota = 0;
        }

        pageContext.setAttribute( "offlinechecktimer", OfflineMessageStore.OFFLINE_AUTOCLEAN_CHECKINTERVAL.getValue().toMinutes() );
        pageContext.setAttribute( "daystolive", OfflineMessageStore.OFFLINE_AUTOCLEAN_DAYSTOLIVE.getValue().toDays() );
        pageContext.setAttribute( "offlinecleaner", OfflineMessageStore.OFFLINE_AUTOCLEAN_ENABLE.getValue()?"true":"" );
    }
    pageContext.setAttribute("errors", errors);
%>

<c:choose>
    <c:when test="${not empty errors}">
        <c:forEach var="err" items="${errors}">
            <admin:infobox type="error">
                <c:choose>
                    <c:when test="${err.key eq 'csrf'}"><fmt:message key="global.csrf.failed" /></c:when>
                    <c:otherwise>
                        <c:if test="${not empty err.value}">
                            <fmt:message key="admin.error"/>: <c:out value="${err.value}"/>
                        </c:if>
                        (<c:out value="${err.key}"/>)
                    </c:otherwise>
                </c:choose>
            </admin:infobox>
        </c:forEach>
    </c:when>
    <c:when test="${success}">
        <admin:infoBox type="success">
            <fmt:message key="offline.messages.update" />
        </admin:infoBox>
    </c:when>
</c:choose>

<p>
<fmt:message key="offline.messages.info" />
</p>

<p>
<fmt:message key="offline.messages.size" />
<b><%= format.format(OfflineMessageStore.getInstance().getSize()/1024.0/1024.0) %> MB</b>
</p>



<!-- BEGIN 'Offline Message Policy' -->
<form action="offline-messages.jsp">
    <input type="hidden" name="csrf" value="${csrf}">
    <div class="jive-contentBoxHeader">
        <fmt:message key="offline.messages.policy" />
    </div>
    <div class="jive-contentBox">
        <table>
        <tbody>
            <tr class="">
                <td style="width: 1%; white-space: nowrap">
                    <input type="radio" name="strategy" value="<%= STORE %>" id="rb03"
                     <%= ((strategy==STORE) ? "checked" : "") %>>
                </td>
                <td>
                    <label for="rb03"><b><fmt:message key="offline.messages.store_option" /></b></label> - <fmt:message key="offline.messages.storage_openfire" />
                </td>
            </tr>
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    &nbsp;
                </td>
                <td>

                    <table>
                    <tr>
                        <td style="width: 1%; white-space: nowrap">
                            <input type="radio" name="storeStrategy" value="<%= STORE_AND_BOUNCE%>" id="rb06"
                             onclick="this.form.strategy[0].checked=true;"
                             <%= ((storeStrategy==STORE_AND_BOUNCE) ? "checked" : "") %>>
                        </td>
                        <td>
                            <label for="rb06"><b><fmt:message key="offline.messages.bounce" /></b></label> - <fmt:message key="offline.messages.bounce_info" />
                        </td>
                    </tr>
                    <tr>
                        <td style="width: 1%; white-space: nowrap">
                            <input type="radio" name="storeStrategy" value="<%= ALWAYS_STORE %>" id="rb05"
                             onclick="this.form.strategy[0].checked=true;"
                             <%= ((storeStrategy==ALWAYS_STORE) ? "checked" : "") %>>
                        </td>
                        <td>
                            <label for="rb05"><b><fmt:message key="offline.messages.always_store" /></b></label> - <fmt:message key="offline.messages.always_store_info" />
                        </td>
                    </tr>
                    <tr>
                        <td style="width: 1%; white-space: nowrap">
                            <input type="radio" name="storeStrategy" value="<%= STORE_AND_DROP %>" id="rb07"
                             onclick="this.form.strategy[0].checked=true;"
                             <%= ((storeStrategy==STORE_AND_DROP) ? "checked" : "") %>>
                        </td>
                        <td>
                            <label for="rb07"><b><fmt:message key="offline.messages.drop" /></b></label> - <fmt:message key="offline.messages.drop_info" />
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2">
                            <label for="quota"><fmt:message key="offline.messages.storage_limit" /></label>
                            <input type="text" size="5" maxlength="12" id="quota" name="quota"
                             value="<%= (quota>0 ? ""+format.format(quota) : "") %>"
                             onclick="this.form.strategy[0].checked=true;">
                            KB
                        </td>
                    </tr>
                    </table>
                </td>
            </tr>
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    <input type="radio" name="strategy" value="<%= BOUNCE %>" id="rb01"
                     <%= ((strategy==BOUNCE) ? "checked" : "") %>>
                </td>
                <td>
                    <label for="rb01"><b><fmt:message key="offline.messages.bounce_option" /></b></label> - <fmt:message key="offline.messages.never_back" />
                </td>
            </tr>
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    <input type="radio" name="strategy" value="<%= DROP %>" id="rb02"
                     <%= ((strategy==DROP) ? "checked" : "") %>>
                </td>
                <td>
                    <label for="rb02"><b><fmt:message key="offline.messages.drop_option" /></b></label> - <fmt:message key="offline.messages.never_store" />
                </td>
            </tr>
        </tbody>
        </table>
    </div>
    <br/>
    <div class="jive-contentBoxHeader">
        <fmt:message key="offline.messages.clean.title" />
    </div>
    <div class="jive-contentBox">
        <table>
            <tbody>
                <tr>
                    <td colspan="2">
                        <fmt:message key="offline.messages.clean.description" />
                    </td>
                </tr>
                <tr>
                    <td style="width: 1%; white-space: nowrap">
                        <b>
                            <label for="offlinecleaner">
                                <fmt:message key="offline.messages.clean.label" />
                            </label>
                        </b>
                    </td>
                    <td>
                        <input type="checkbox" name="offlinecleaner" id="offlinecleaner" size="5" ${offlinecleaner ? "checked" : ""} >
                    </td>
                </tr>
                <tr>
                    <td colspan="2">
                        <fmt:message key="offline.messages.clean.timer.description" />
                    </td>
                </tr>
                <tr>
                    <td style="width: 1%; white-space: nowrap">
                        <b>
                            <label for="offlinechecktimer">
                                <fmt:message key="offline.messages.clean.timer.label" />
                            </label>
                        </b>
                    </td>
                    <td>
                        <input type="number" min="1" name="offlinechecktimer" id="offlinechecktimer" size="5" value="${offlinechecktimer}">
                    </td>
                </tr>
                <tr>
                    <td colspan="2">
                        <fmt:message key="offline.messages.clean.daystolive.description" />
                    </td>
                </tr>
                <tr>
                    <td style="width: 1%; white-space: nowrap">
                        <b>
                            <label for="daystolive">
                                <fmt:message key="offline.messages.clean.daystolive.label" />
                            </label>
                        </b>
                    </td>
                    <td>
                        <input type="number" min="1" name="daystolive" id="daystolive" size="5" value="${daystolive}">
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
    <input type="submit" name="update" value="<fmt:message key="global.save_settings" />">
</form>
<!-- END 'Offline Message Policy' -->


</body>
</html>
