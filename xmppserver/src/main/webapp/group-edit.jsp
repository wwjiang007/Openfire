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

<%@ page import="gnu.inet.encoding.Stringprep"%>
<%@ page import="org.jivesoftware.openfire.group.Group"%>
<%@ page import="org.jivesoftware.openfire.group.GroupManager"%>
<%@ page import="org.jivesoftware.openfire.group.GroupNotFoundException"%>
<%@ page import="org.jivesoftware.openfire.security.SecurityAuditManager"%>
<%@ page import="org.jivesoftware.openfire.user.UserManager"%>
<%@ page import="org.jivesoftware.openfire.user.UserNotFoundException"%>
<%@ page import="org.jivesoftware.util.CookieUtils"%>
<%@ page import="org.jivesoftware.util.ParamUtils"%>
<%@ page import="org.jivesoftware.util.StringUtils"%>
<%@ page import="org.jivesoftware.util.ListPager" %>
<%@ page import="org.xmpp.packet.JID"%>
<%@ page import="java.io.UnsupportedEncodingException"%>
<%@ page import="java.net.URLDecoder" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.util.*" %>
<%@ page import="java.util.function.Predicate" %>
<%@ page import="org.slf4j.LoggerFactory" %>
<%@ page import="org.jivesoftware.openfire.group.SharedGroupVisibility" %>
<%@ page import="java.nio.charset.StandardCharsets" %>

<%@ taglib uri="admin" prefix="admin" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/functions" prefix="fn" %>

<!-- Define Administration Bean -->
<jsp:useBean id="webManager" class="org.jivesoftware.util.WebManager"/>

<%  webManager.init(pageContext); %>

<%  // Get parameters
    boolean updateDetails = request.getParameter( "updateDetails" ) != null;
    boolean addMember = request.getParameter( "addMember") != null;
    boolean removeMember = request.getParameter( "removeMember") != null;
    boolean updateMember = request.getParameter("updateMember") != null;
    boolean updateContactListSettings = request.getParameter("updateContactListSettings") != null;
    boolean cancel = request.getParameter("cancel") != null;

    String name = ParamUtils.getParameter( request, "name" ); // update for group name
    String description = ParamUtils.getParameter( request, "description" ); // update for group description.

    String username = ParamUtils.getParameter(request, "username");
    String [] adminJIDs = ParamUtils.getParameters(request, "admin");
    String [] deleteMembers = ParamUtils.getParameters(request, "delete");
    String groupName = ParamUtils.getParameter(request, "group");
    GroupManager groupManager = webManager.getGroupManager();
    boolean groupInfoChanged = ParamUtils.getBooleanParameter(request, "groupChanged", false);

    Map<String,String> errors = new HashMap<>();

    boolean enableRosterGroups = ParamUtils.getBooleanParameter(request,"enableRosterGroups");
    String groupDisplayName = ParamUtils.getParameter(request,"groupDisplayName");
    String showGroup = ParamUtils.getParameter(request,"showGroup");
    List<String> groupNames = Arrays.asList(ParamUtils.getParameters(request, "groupNames"));

    Group group = groupManager.getGroup(groupName);
    boolean success;
    Cookie csrfCookie = CookieUtils.getCookie(request, "csrf");
    String csrfParam = ParamUtils.getParameter(request, "csrf");

    if ( addMember || removeMember || updateMember || updateContactListSettings || updateDetails ) {
        if (csrfCookie == null || csrfParam == null || !csrfCookie.getValue().equals(csrfParam)) {
            addMember = false;
            removeMember = false;
            updateContactListSettings = false;
            updateMember = false;
            updateDetails = false;
            errors.put("csrf", "CSRF Failure!");
        }
    }
    csrfParam = StringUtils.randomString(15);
    CookieUtils.setCookie(request, response, "csrf", csrfParam, -1);
    pageContext.setAttribute("csrf", csrfParam);

    if (cancel) {
        response.sendRedirect("group-summary.jsp");
        return;
    }

    // Handle a request to update the group details (name, description).
    if ( updateDetails )
    {
        // Validate
        if ( name == null || name.trim().isEmpty() )
        {
            errors.put( "name", "Name cannot be null or empty." );
        }
        else if ( !groupName.equalsIgnoreCase( name.trim() ) )
        {
            try
            {
                webManager.getGroupManager().getGroup( name.trim(), true );
                errors.put( "alreadyExists", name.trim() );
            }
            catch ( GroupNotFoundException e)
            {
                // intended.
            }
        }

        if ( errors.isEmpty() )
        {
            try
            {
                webManager.getGroupManager().getGroup( groupName );
                group.setName( name.trim() );
                group.setDescription( description != null ? description.trim() : null );

                if ( !SecurityAuditManager.getSecurityAuditProvider().blockGroupEvents() )
                {
                    // Log the event
                    webManager.logEvent( "edited group " + groupName, "name = " + group.getName() + ",description = " + group.getDescription() );
                }

                // Successful, so redirect
                response.sendRedirect( "group-edit.jsp?groupChanged=true&group=" + URLEncoder.encode( group.getName(), StandardCharsets.UTF_8)
                    + ListPager.getQueryString(request, '&', "searchName") );
                return;
            }
            catch ( Exception e )
            {
                errors.put( "general", e.getMessage() );
            }
        }
    }

    // Handle a request to update the contact list settings.
    if ( updateContactListSettings )
    {
        if (enableRosterGroups && (groupDisplayName == null || groupDisplayName.trim().isEmpty()))
        {
            errors.put("groupDisplayName", "Group display name cannot be null or empty.");
        }

        if (errors.isEmpty())
        {
            if (enableRosterGroups)
            {
                if ( !"spefgroups".equals( showGroup ) )
                {
                    // not spefgroups? Either 'everybody' or 'onlyGroup' - in any case, no 'groupList' should be empty.
                    groupNames = new ArrayList<>();
                }

                if ("everybody".equals(showGroup)) {
                    group.shareWithEverybody(groupDisplayName.trim());
                } else if ("spefgroups".equals(showGroup)) {
                    // The stored value for 'showInRoster' is either 'onlyGroup' or 'everybody', when sharing is enabled
                    // 'spefgroups' isn't actually saved. That's represented by 'onlyGroup' combined with a 'groupList'.
                    group.shareWithUsersInGroups(toList( groupNames.toArray( new String[]{} ) ), groupDisplayName.trim());
                    showGroup = "onlyGroup";
                } else {
                    group.shareWithUsersInSameGroup(groupDisplayName.trim());
                }

                if (!SecurityAuditManager.getSecurityAuditProvider().blockGroupEvents()) {
                    // Log the event
                    webManager.logEvent("enabled roster groups for "+groupName, "showinroster = "+showGroup+"\ndisplayname = "+groupDisplayName+"\ngrouplist = "+toList(groupNames.toArray( new String[]{} ) ));
                }
            }
            else
            {
                group.shareWithNobody();

                if (!SecurityAuditManager.getSecurityAuditProvider().blockGroupEvents()) {
                    // Log the event
                    webManager.logEvent("disabled roster groups for "+groupName, null);
                }
            }

            // Get admin list and compare it the admin posted list.
            response.sendRedirect("group-edit.jsp?group=" + URLEncoder.encode(groupName, StandardCharsets.UTF_8) + "&groupChanged=true"
                + ListPager.getQueryString(request, '&', "searchName") );
            return;
        }
    }

    // Handle a request to update the privilege of an existing group member.
    if (errors.isEmpty() && updateMember)
    {
        final Set<JID> newAdmins = new HashSet<>();
        for ( final String adminJID : adminJIDs )
        {
            newAdmins.add( new JID( adminJID ) );
        }

        // Process changes to admins. First, add users that are newly marked as 'admin'...
        for ( final JID newAdmin : newAdmins )
        {
            if ( !group.getAdmins().contains( newAdmin ) )
            {
                group.getAdmins().add( newAdmin );
            }
        }

        // ... all users that are unmarked should be moved from the 'admins' group to the 'members' group.
        final Set<JID> oldAdmins = new HashSet<>( group.getAdmins() );
        oldAdmins.removeAll( newAdmins ); // All left are no longer supposed to be admins.
        for ( final JID oldAdmin : oldAdmins )
        {
            // Update privilege by explicitly adding the old admin to the member group.
            group.getMembers().add(oldAdmin);
        }

        if (!SecurityAuditManager.getSecurityAuditProvider().blockGroupEvents())
        {
            // Log the event
            webManager.logEvent("updated group membership for "+groupName, null);
        }

        // Get admin list and compare it the admin posted list.
        response.sendRedirect("group-edit.jsp?group=" + URLEncoder.encode(groupName, StandardCharsets.UTF_8) + "&updatesuccess=true"
            + ListPager.getQueryString(request, '&', "searchName") );
        return;
    }

    // Handle a request to add a new group member.
    if ( errors.isEmpty() && addMember)
    {
        if ( username == null || username.trim().isEmpty() )
        {
            errors.put( "addMember", "username" );
        }
        else
        {
            boolean memberAdded = false;
            username = username.trim();
            username = username.toLowerCase();

            if ( username.contains( "@" ) )
            {
                try
                {
                    UserManager.getInstance().getUser( JID.escapeNode( username ) );
                    // That means that this user has an email address as their node.
                    username = JID.escapeNode( username );
                }
                catch (UserNotFoundException e)
                {
                    // that's ok.
                }
            }

            // Add to group as member by default.
            try
            {
                if ( !username.contains( "@" ) )
                {
                    // No @ was found so assume this is a JID of a local user
                    username = JID.escapeNode(username);
                    username = Stringprep.nodeprep(username);
                    UserManager.getInstance().getUser(username);
                    memberAdded = group.getMembers().add(webManager.getXMPPServer().createJID(username, null));
                }
                else
                {
                    // Admin entered a JID. Add the JID directly to the list of group members
                    memberAdded = group.getMembers().add( new JID(username) );
                    if (!SecurityAuditManager.getSecurityAuditProvider().blockGroupEvents()) {
                        // Log the event
                        webManager.logEvent("added group member to "+groupName, "username = "+username);
                    }
                }
            }
            catch ( Exception e )
            {
                errors.put( "general", e.getMessage() );
                LoggerFactory.getLogger("group-edit.jsp").warn("Problem adding new user '{}' to existing group '{}' in admin console.", groupName, username, e);
            }

            if ( memberAdded )
            {
                response.sendRedirect("group-edit.jsp?group=" + URLEncoder.encode(groupName, StandardCharsets.UTF_8) + "&success=true"
                    + ListPager.getQueryString(request, '&', "searchName") );
                return;
            }
        }
    }

    // Handle a request to remove group members.
    if ( errors.isEmpty() && removeMember ) {
        for (String deleteMember : deleteMembers) {
            JID member = new JID(deleteMember);
            group.getMembers().remove(member);
            group.getAdmins().remove(member);
        }
        response.sendRedirect("group-edit.jsp?group=" + URLEncoder.encode(groupName, StandardCharsets.UTF_8) + "&deletesuccess=true"
            + ListPager.getQueryString(request, '&', "searchName") );
        return;
    }

    success = groupInfoChanged || "true".equals(request.getParameter("success")) ||
            "true".equals(request.getParameter("deletesuccess")) ||
            "true".equals(request.getParameter("updatesuccess")) ||
            "true".equals(request.getParameter("creategroupsuccess"));

    SharedGroupVisibility visibility = group.getSharedWith();
    if ( SharedGroupVisibility.usersOfGroups == visibility ) {
        groupNames = group.getSharedWithUsersInGroupNames();
    }

    pageContext.setAttribute( "success", success );
    pageContext.setAttribute( "errors", errors );
    pageContext.setAttribute( "groupInfoChanged", groupInfoChanged );
    pageContext.setAttribute( "group", group );
    pageContext.setAttribute( "onlySharedWithOwnGroup", groupNames.isEmpty() || (groupNames.size() == 1 && groupNames.contains(group.getName())));
    pageContext.setAttribute( "groupNames", groupNames );

    final List<JID> allMembers = new ArrayList<>();
    allMembers.addAll( group.getAdmins() );
    allMembers.addAll( group.getMembers() );
    Collections.sort( allMembers );
    Predicate<JID> filter = jid -> true;
    final String searchName = ParamUtils.getStringParameter(request, "searchName", "").trim();
    if(!searchName.isEmpty()) {
        filter = filter.and(jid -> StringUtils.containsIgnoringCase(jid.toString(), searchName));
    }
    final ListPager<JID> listPager = new ListPager<>(request, response, allMembers, filter, "group", "searchName");
    pageContext.setAttribute( "listPager", listPager );
    pageContext.setAttribute("searchName", searchName);

    final List<Group> groups = new ArrayList<>(groupManager.getGroups());
    groups.sort(Comparator.comparing(Group::getName));
    pageContext.setAttribute("groups", groups);
%>

<html>
<head>
<title><fmt:message key="group.edit.title"/></title>
<meta name="subPageID" content="group-edit"/>
<meta name="extraParams" content="group=${admin:urlEncode(group.name)}"/>
<meta name="helpPage" content="edit_group_properties.html"/>
</head>
<body>

<p>
    <fmt:message key="group.edit.form_info" />
</p>

<c:if test="${not empty errors['general']}">
    <admin:infobox type="error">
        <fmt:message key="group.edit.error" />
    </admin:infobox>
</c:if>
<c:if test="${not empty errors['csrf']}">
    <admin:infobox type="error">
        <fmt:message key="global.csrf.failed" />
    </admin:infobox>
</c:if>

<c:if test="${empty errors and success}">
    <admin:infobox type="success">
        <c:choose>
            <c:when test="${groupInfoChanged}">
                <fmt:message key="group.edit.update" />
            </c:when>
            <c:when test="${param.success}">
                <fmt:message key="group.edit.update_add_user" />
            </c:when>
            <c:when test="${param.deletesuccess}">
                <fmt:message key="group.edit.update_del_user" />
            </c:when>
            <c:when test="${param.updatesuccess}">
                <fmt:message key="group.edit.update_user" />
            </c:when>
            <c:when test="${param.creategroupsuccess}">
                <fmt:message key="group.edit.update_success" />
            </c:when>
            <c:otherwise>
                <fmt:message key="group.edit.update" />
            </c:otherwise>
        </c:choose>
    </admin:infobox>
</c:if>

<!-- BEGIN group name and description -->
<fmt:message key="group.edit.edit_details" var="groupdetailsboxtitle"/>
<admin:contentBox title="${groupdetailsboxtitle}">

    <form name="groupdetails">
        <input type="hidden" name="csrf" value="${csrf}">
        <input type="hidden" name="group" value="${fn:escapeXml(param.group)}"/>
        ${listPager.hiddenFields}

        <c:if test="${webManager.groupManager.readOnly}">
            <admin:infobox type="info"><fmt:message key="group.read_only"/></admin:infobox>
        </c:if>

        <table style="width: 80%">
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    <label for="gname"><fmt:message key="group.create.group_name" /></label> *
                </td>
                <td>
                    <input type="text" name="name" size="50" maxlength="50" value="${fn:escapeXml(group.name)}" id="gname" ${webManager.groupManager.readOnly ? 'readonly' : ''} />
                </td>
            </tr>
            <c:if test="${not empty errors['name'] or not empty errors['alreadyExists']}">
                <tr>
                    <td></td>
                    <td>
                        <span class="jive-error-text">
                            <c:if test="${not empty errors['name']}"><fmt:message key="group.create.invalid_group_name" /></c:if>
                            <c:if test="${not empty errors['alreadyExists']}"><fmt:message key="group.create.invalid_group_info" /></c:if>
                        </span>
                    </td>
                </tr>
            </c:if>
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    <label for="gdesc"><fmt:message key="group.create.label_description" /></label>
                </td>
                <td>
                    <textarea name="description" cols="75" rows="3" maxlength="255" id="gdesc" ${webManager.groupManager.readOnly ? 'readonly' : ''}><c:out value="${group.description}"/></textarea>
                </td>
            </tr>
            <c:if test="${not empty errors['description']}">
                <tr>
                    <td></td>
                    <td>
                        <span class="jive-error-text"><fmt:message key="group.create.invalid_description" /></span>
                    </td>
                </tr>
            </c:if>
            <c:if test="${not webManager.groupManager.readOnly}">
                <tr>
                    <td></td>
                    <td>
                        <input type="submit" name="updateDetails" value="<fmt:message key="global.save_settings" />">
                    </td>
                </tr>
            </c:if>
        </table>

        <span class="jive-description">* <fmt:message key="group.create.required_fields" /> </span>
    </form>
</admin:contentBox>
<!-- END group name and description -->


<!-- BEGIN contact list settings -->
<fmt:message key="group.edit.share_title" var="contactlistsettingsboxtitle"/>
<admin:contentBox title="${contactlistsettingsboxtitle}">

    <form name="groupshare">
        <input type="hidden" name="csrf" value="${csrf}">
        <input type="hidden" name="group" value="${fn:escapeXml(param.group)}"/>
        ${listPager.hiddenFields}

        <p>
            <fmt:message key="group.edit.share_content" />
        </p>

        <table style="width: 80%">
            <tr>
                <td style="width: 1%; white-space: nowrap">
                    <input type="radio" name="enableRosterGroups" value="false" id="rb201" ${empty group.properties['sharedRoster.showInRoster'] or group.properties['sharedRoster.showInRoster'] eq 'nobody' ? "checked" : ""} onClick="toggleReadOnly();">
                </td>
                <td>
                    <label for="rb201"><fmt:message key="group.edit.share_not_in_rosters" /></label>
                </td>
            </tr>
            <tr>
                <td style="width: 1%; white-space: nowrap; vertical-align: top">
                    <input type="radio" name="enableRosterGroups" value="true" id="rb202" ${empty group.properties['sharedRoster.showInRoster'] or group.properties['sharedRoster.showInRoster'] eq 'nobody' ? "" : "checked"} onClick="toggleReadOnly();"">
                </td>
                <td>
                    <label for="rb202"><fmt:message key="group.edit.share_in_rosters" /></label>

                    <div id="jive-roster">
                        <b><label for="groupDisplayName"><fmt:message key="group.edit.share_display_name" /></label></b>
                        <p><input type="text" id="groupDisplayName" name="groupDisplayName" size="45" maxlength="100" value="${fn:escapeXml(group.properties['sharedRoster.displayName'])}">
                        <c:if test="${not empty errors['groupDisplayName']}">
                            <br><span class="jive-error-text"><fmt:message key="group.edit.share_display_name" /></span>
                        </c:if>
                        </p>
                        <p><b><fmt:message key="group.edit.share_with"/></b></p>
                        <table>
                            <tr>
                                <td style="width: 1%; white-space: nowrap">
                                    <input type="radio" name="showGroup" value="onlyGroup" id="rb001" ${( group.sharedWith eq "nobody" ) or ( group.sharedWith eq "usersOfGroups" and onlySharedWithOwnGroup ) ? "checked" : "" }>
                                </td>
                                <td>
                                    <label for="rb001"><fmt:message key="group.edit.share_group_only" /></label>
                                </td>
                            </tr>
                            <tr>
                                <td style="width: 1%; white-space: nowrap">
                                    <input type="radio" name="showGroup" value="everybody" id="rb002" ${group.sharedWith eq "everybody" ? "checked" : ""}>
                                </td>
                                <td>
                                    <label for="rb002"><fmt:message key="group.edit.share_all_users" /></label>
                                </td>
                            </tr>
                            <tr>
                                <td style="width: 1%; white-space: nowrap">
                                    <input type="radio" name="showGroup" value="spefgroups" id="rb003" ${group.sharedWith eq "usersOfGroups" and not onlySharedWithOwnGroup ? "checked" : ""}>
                                </td>
                                <td>
                                    <label for="rb003"><fmt:message key="group.edit.share_roster_groups" /></label>
                                </td>
                            </tr>
                            <tr>
                                <td style="width: 1%; white-space: nowrap"></td>
                                <td>
                                    <select name="groupNames" id="groupNames" size="6" onclick="this.form.showGroup[2].checked=true;"
                                            multiple style="width:340px;font-family:verdana,arial,helvetica,sans-serif;font-size:8pt;">

                                        <c:forEach var="g" items="${groups}">
                                            <!-- Do not offer the edited group in the list of groups. Members of the editing group can always see each other -->
                                            <c:if test="${not g.equals(group)}">
                                                <option value="${fn:escapeXml(g.name)}" ${groupNames.contains(g.name) ? "selected": ""}>
                                                    <c:out value="${g.name}"/>
                                                </option>
                                            </c:if>
                                        </c:forEach>
                                    </select>
                                </td>
                            </tr>
                        </table>
                    </div>
                </td>
            </tr>
            <tr>
                <td style="width: 1%; white-space: nowrap"></td>
                <td>
                    <input type="submit" name="updateContactListSettings" value="<fmt:message key="group.edit.share_save" />">
                </td>
            </tr>
        </table>

    </form>
</admin:contentBox>
<!-- END contact list settings -->

<!-- BEGIN group membership management -->
<fmt:message key="group.edit.members" var="groupmembersboxtitle"/>
<admin:contentBox title="${groupmembersboxtitle}">

    <c:if test="${webManager.groupManager.readOnly}">
        <admin:infobox type="info"><fmt:message key="group.read_only"/></admin:infobox>
    </c:if>

    <c:if test="${not webManager.groupManager.readOnly}">
        <p>
            <fmt:message key="group.edit.members_description" />
        </p>

        <form name="groupmembers" method="post">
            <input type="hidden" name="csrf" value="${csrf}">
            <input type="hidden" name="group" value="${fn:escapeXml(param.group)}"/>
            <input type="hidden" name="addMember" value="addMember"/>
            ${listPager.hiddenFields}

            <table style="margin: 0 0 8px 0;">
                <tr>
                    <td style="width: 1%; white-space: nowrap">
                        <fmt:message key="group.edit.add_user" />
                    </td>
                    <td class="c1" style="text-align: left; white-space: nowrap">
                         <input type="text" size="45" name="username" autocomplete="off"/>
                        &nbsp;<input type="submit" name="addbutton" value="<fmt:message key="global.add" />">
                    </td>
                    <c:if test="${not empty errors['addMember']}">
                        <td>
                            <span class="jive-error-text"><fmt:message key="group.edit.invalid_username"/></span>
                        </td>
                    </c:if>
                </tr>
            </table>
        </form>

    </c:if>

    <fmt:message key="user.summary.total_user" />: <b>${listPager.totalItemCount}</b>
    <c:if test="${listPager.filtered}">
        <fmt:message key="user.summary.filtered_users_count" />: <c:out value="${listPager.filteredItemCount}"/>
    </c:if>
    <c:if test="${listPager.totalPages > 1}">
        -- <fmt:message key="global.showing" /> <c:out value="${listPager.firstItemNumberOnPage}"/>-<c:out value="${listPager.lastItemNumberOnPage}"/>
        <p><fmt:message key="global.pages" />: [ ${listPager.pageLinks} ]
    </c:if>
    -- <fmt:message key="user.summary.users_per_page" />:
    ${listPager.pageSizeSelection}

    <form method="post" name="main">
        <input type="hidden" name="csrf" value="${csrf}">
        <input type="hidden" name="group" value="${fn:escapeXml(param.group)}"/>
        ${listPager.hiddenFields}
        <table class="jive-table" style="width: 80%">
            <tr>
                <th>&nbsp;</th>
                <th nowrap><fmt:message key="group.edit.username" /></th>
                <th nowrap><fmt:message key="group.edit.name" /></th>
                <c:if test="${not webManager.groupManager.readOnly}">
                    <th style="width: 1%; white-space: nowrap" class="jive-table-th-center"><fmt:message key="group.edit.admin" /></th>
                    <th style="width: 1%; white-space: nowrap" class="jive-table-th-center"><fmt:message key="group.edit.remove" /></th>
                </c:if>
            </tr>

            <c:set var="showRemoteJIDsWarning" value="false"/>

            <c:if test="${listPager.totalItemCount == 0}">
                <tr>
                    <td style="text-align: center" colspan="5">
                        <br>
                        <fmt:message key="group.edit.user_hint" />
                        <br>
                        <br>
                    </td>
                </tr>
            </c:if>
            <c:if test="${listPager.totalItemCount > 0}">
                <tr>
                    <th></th>
                    <th nowrap>
                        <input type="search"
                               id="searchName"
                               size="20"
                               value="<c:out value="${searchName}"/>"/>
                        <img src="images/search-16x16.png"
                             width="16" height="16"
                             alt="search" title="search"
                             style="vertical-align: middle;"
                             onclick="submitForm();"
                        >
                    </th>
                    <th><!-- TODO: add search for full name here --></th>
                    <c:if test="${not webManager.groupManager.readOnly}">
                        <th></th>
                        <th></th>
                    </c:if>
                </tr>
            </c:if>
            <%--@elvariable id="member" type="org.xmpp.packet.JID"--%>
            <c:forEach var="member" items="${listPager.itemsOnCurrentPage}">
                <tr>
                    <td style="width: 1%">

                        <c:choose>
                            <c:when test="${webManager.XMPPServer.isLocal(member)}">
                                <c:choose>
                                    <c:when test="${webManager.userManager.isRegisteredUser(member, false) and webManager.presenceManager.isAvailable(webManager.userManager.getUser(member))}">
                                        <c:choose>
                                            <c:when test="${empty webManager.presenceManager.getPresence(webManager.userManager.getUser(member)).show}">
                                                <img src="images/im_available.gif" title="<fmt:message key="user.properties.available" />" alt="<fmt:message key="user.properties.available" />">
                                            </c:when>
                                            <c:when test="${webManager.presenceManager.getPresence(webManager.userManager.getUser(member)).show == 'chat'}">
                                                <img src="images/im_free_chat.gif" title="<fmt:message key="session.details.chat_available" />" alt="<fmt:message key="session.details.chat_available" />">
                                            </c:when>
                                            <c:when test="${webManager.presenceManager.getPresence(webManager.userManager.getUser(member)).show == 'away'}">
                                                <img src="images/im_away.gif" title="<fmt:message key="session.details.away" />" alt="<fmt:message key="session.details.away" />">
                                            </c:when>
                                            <c:when test="${webManager.presenceManager.getPresence(webManager.userManager.getUser(member)).show == 'xa'}">
                                                <img src="images/im_away.gif" title="<fmt:message key="session.details.extended" />" alt="<fmt:message key="session.details.extended" />">
                                            </c:when>
                                            <c:when test="${webManager.presenceManager.getPresence(webManager.userManager.getUser(member)).show == 'dnd'}">
                                                <img src="images/im_dnd.gif" title="<fmt:message key="session.details.not_disturb" />" alt="<fmt:message key="session.details.not_disturb" />">
                                            </c:when>
                                        </c:choose>
                                    </c:when>
                                    <c:otherwise>
                                        <img src="images/im_unavailable.gif" title="<fmt:message key="user.properties.offline" />" alt="<fmt:message key="user.properties.offline" />">
                                    </c:otherwise>
                                </c:choose>
                            </c:when>
                            <c:otherwise>
                                <c:set var="showRemoteJIDsWarning" value="true"/>
                                &nbsp;
                            </c:otherwise>
                        </c:choose>
                    </td>
                    <td>
                        <c:choose>
                            <c:when test="${webManager.userManager.isRegisteredUser(member, false)}">
                                <a href="user-properties.jsp?username=${admin:urlEncode(webManager.userManager.getUser(member).username)}">
                                    <c:out value="${webManager.userManager.getUser(member).username}"/>
                                </a>
                            </c:when>
                            <c:otherwise>
                                <c:out value="${member}"/> <span style="color: red; "><b>*</b></span>
                            </c:otherwise>
                        </c:choose>
                    </td>
                    <td>
                        <c:if test="${webManager.userManager.isRegisteredUser(member, false)}">
                            <c:out value="${webManager.userManager.getUser(member).name}"/>
                        </c:if>
                    </td>
                    <c:if test="${not webManager.groupManager.readOnly}">
                        <td style="text-align: center">
                            <input type="checkbox" name="admin" value="${fn:escapeXml(member)}" ${group.admins.contains(member) ? 'checked' : ''}>
                        </td>
                        <td style="text-align: center">
                            <input type="checkbox" name="delete" value="${fn:escapeXml(member)}">
                        </td>
                    </c:if>
                </tr>
            </c:forEach>

            <c:if test="${ ( listPager.totalItemCount != 0 ) and (not webManager.groupManager.readOnly)}">
                <tr>
                    <td colspan="3">&nbsp;</td>
                    <td style="text-align: center">
                        <input type="submit" name="updateMember" value="Update">
                    </td>
                    <td style="text-align: center">
                        <input type="submit" name="removeMember" value="Remove">
                    </td>
                </tr>
            </c:if>
        </table>

        <c:if test="${showRemoteJIDsWarning}">
            <span class="jive-description"><span style="color: red; ">* <fmt:message key="group.edit.note" /></span></span>
        </c:if>

    </form>
    <c:if test="${listPager.totalPages > 1}">
        <p><fmt:message key="global.pages" />: [ ${listPager.pageLinks} ]</p>
    </c:if>

    ${listPager.jumpToPageForm}

    <script>
        ${listPager.pageFunctions}
        document.groupmembers["username"].focus();
    </script>

</admin:contentBox>
<!-- END group membership management -->

<script>
    function toggleReadOnly()
    {
        let disabled = document.getElementById('rb201').checked;

        document.getElementById( 'groupDisplayName' ).disabled = disabled;
        document.getElementById( 'rb001' ).disabled = disabled;
        document.getElementById( 'rb002' ).disabled = disabled;
        document.getElementById( 'rb003' ).disabled = disabled;
        document.getElementById( 'groupNames' ).disabled = disabled;
    }
    toggleReadOnly();
</script>

</body>
</html>


<%!
    private static List<String> toList( String[] array ) {
        List<String> result = new ArrayList<>();
        if (array == null || array.length == 0) {
            return result;
        }
        for (String anArray : array) {
            String item;
            item = URLDecoder.decode( anArray, StandardCharsets.UTF_8);
            result.add(item);
        }
        return result;
    }
%>
