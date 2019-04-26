// This file contains your Data Connector logic
section ServiceNowTableConnector;

windowWidth = 600;
windowHeight = 800;
client_id = Text.FromBinary(Extension.Contents("client_id"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

DefaultRequestHeaders = [
    #"Accept" = "application/json",
    #"Authorization" = CurrentCredential()
];

[DataSource.Kind="ServiceNowTableConnector", Publish="ServiceNowTableConnector.Publish"]
shared ServiceNowTableConnector.Contents = Value.ReplaceType(ServiceNowTableImpl, ServiceNowTableType);

ServiceNowTableType = type function (
    instance as (Uri.Type meta [
        Documentation.FieldCaption = "Instance",
        Documentation.FieldDescription = "Url of your ServiceNow instance"
    ]),
    optional tableName as (type text meta [
        Documentation.FieldCaption = "Table",
        Documentation.FieldDescription = "Name of the table you want to query"
    ]),
    optional sysparm_query as (type text meta [
        Documentation.FieldCaption = "sysparm_query",
        Documentation.FieldDescription = "An encoded query string used to filter the results (default: active=true)"
    ]),
    optional sysparm_display_value as (type text meta [
        Documentation.FieldCaption = "sysparm_display_value",
        Documentation.FieldDescription = "Return field display values (true), actual values (false), or both (all) (default: false)",
        Documentation.AllowedValues = { "all", "true", "false" }
    ]),
    optional sysparm_exclude_reference_link as (type text meta [
        Documentation.FieldCaption = "sysparm_exclude_reference_link",
        Documentation.FieldDescription = "True to exclude Table API links for reference fields (default: false)",
        Documentation.AllowedValues = { "true", "false" }
    ]),
    optional sysparm_suppress_pagination_header as (type text meta [
        Documentation.FieldCaption = "sysparm_suppress_pagination_header",
        Documentation.FieldDescription = "True to supress pagination header (default: false)",
        Documentation.AllowedValues = { "true", "false" }
    ]),
    optional sysparm_fields as (type text meta [
        Documentation.FieldCaption = "sysparm_fields",
        Documentation.FieldDescription = "A comma-separated list of fields to return in the response"
    ]),
    optional sysparm_limit as (type number meta [
        Documentation.FieldCaption = "sysparm_limit",
        Documentation.FieldDescription = "The maximum number of results returned per page (default: 10,000)"
    ]),
    optional sysparm_view as (type text meta [
        Documentation.FieldCaption = "sysparm_view",
        Documentation.FieldDescription = "Render the response according to the specified UI view (overridden by sysparm_fields)"
    ]),
    optional sysparm_query_category as (type text meta [
        Documentation.FieldCaption = "sysparm_query_category",
        Documentation.FieldDescription = "Name of the query category (read replica category) to use for queries"
    ])
) as table meta [
    Documentation.Name = "ServiceNow Table API"
];

ServiceNowTableImpl = (instance as text, optional tableName as text, optional sysparm_query as text, optional sysparm_display_value as text, optional sysparm_exclude_reference_link as text, optional sysparm_suppress_pagination_header as text, optional sysparm_fields as text, optional sysparm_limit as number, optional sysparm_view as text, optional sysparm_query_category as text) as table =>
    let
        _view = if (sysparm_view <> null) then sysparm_view else "",
        _limit = if (sysparm_limit <> null) then Number.ToText(sysparm_limit) else "10000",
        _query = if (sysparm_query <> null) then sysparm_query else "active=true",
        _fields = if (sysparm_fields <> null) then sysparm_fields else "",
        _display = if (sysparm_display_value <> null) then sysparm_display_value else "false",
        _category = if (sysparm_query_category <> null) then sysparm_query_category else "",
        _reference = if (sysparm_exclude_reference_link <> null) then sysparm_exclude_reference_link else "false",
        _pagination = if (sysparm_suppress_pagination_header <> null) then sysparm_suppress_pagination_header else "false",
        source = Web.Contents(instance & "/api/now/table/" & tableName & "?" & Uri.BuildQueryString([
            sysparm_view = _view,
            sysparm_query = _query,
            sysparm_limit = _limit,
            sysparm_fields = _fields,
            sysparm_display_value = _display,
            sysparm_query_category = _category,
            sysparm_exclude_reference_link = _reference,
            sysparm_suppress_pagination_header = _pagination
        ]), [ Headers = DefaultRequestHeaders ]),
        json = Json.Document(source),
        table = Table.FromList(json[result], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        table2 = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(Table.Column(table, "Column1"){0}))
    in
        table2;

// Data Source Kind description
ServiceNowTableConnector = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin
        ],
        // Key = [],
        UsernamePassword = []
        // Windows = [],
        // Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel"),
    TestConnection = (dataSourcePath) => { "ServiceNowTableConnector.Contents", dataSourcePath, "incident", "", "", "", "", "", 10, "", "" }
];

// Data Source UI publishing description
ServiceNowTableConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = ServiceNowTableConnector.Icons,
    SourceTypeImage = ServiceNowTableConnector.Icons
];

ServiceNowTableConnector.Icons = [
    Icon16 = { Extension.Contents("ServiceNowTableConnector16.png"), Extension.Contents("ServiceNowTableConnector20.png"), Extension.Contents("ServiceNowTableConnector24.png"), Extension.Contents("ServiceNowTableConnector32.png") },
    Icon32 = { Extension.Contents("ServiceNowTableConnector32.png"), Extension.Contents("ServiceNowTableConnector40.png"), Extension.Contents("ServiceNowTableConnector48.png"), Extension.Contents("ServiceNowTableConnector64.png") }
];

// OAuth2 flow definition
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = Uri.GetHost(resourceUrl) & "/oauth_auth.do?" & Uri.BuildQueryString([
            client_id = client_id,
            response_type = "token",
            redirect_uri = redirect_uri
        ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        fixed = Text.Replace(callbackUri, "#", "?"),
        token = Uri.Parts(fixed)[Query][access_token],
        jsonb = Json.FromValue([
            token_type = "Bearer",
            access_token = token
        ]),
        body = Json.Document(jsonb)
    in
        body;

// TokenMethod = (resourceUrl, grantType, tokenField, code) =>
//     let
//         queryString = [
//             grant_type = grantType,
//             redirect_uri = redirect_uri
//         ],
//         queryWithCode = Record.AddField(queryString, tokenField, code),
// 
//         res = Web.Contents(Uri.GetHost(resourceUrl) & "/oauth_token.do",
//         [
//             Headers =
//             [
//                 #"Accept" = "application/json",
//                 #"Authorization" = CurrentClientCredential(),
//                 #"Content-type" = "application/x-www-form-urlencoded"
//             ],
//             Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode))
//         ]),
//         body = Json.Document(res)
//     in
//         body;

//Refresh = (resourceUrl, refresh_token) => TokenMethod(resourceUrl, "refresh_token", "refresh_token", refresh_token);

CurrentCredential = () =>
    let
        cred = Extension.CurrentCredential(),
        auth = if (cred[AuthenticationKind] = "UsernamePassword") then "Basic " & Binary.ToText(Text.ToBinary(cred[Username] & ":" & cred[Password]),0) else if (cred[AuthenticationKind] = "OAuth") then "Bearer " & cred[access_token] else ""
    in
        auth;

//CurrentClientCredential = () => "Basic " & Binary.ToText(Text.ToBinary(client_id & ":" & client_secret),0);

Uri.GetHost = (url) =>
    let
        parts = Uri.Parts(url),
        port = if (parts[Scheme] = "https" and parts[Port] = 443) or (parts[Scheme] = "http" and parts[Port] = 80) then "" else ":" & Text.From(parts[Port])
    in
        parts[Scheme] & "://" & parts[Host] & port;


// OAuth2 flow definition
// StartLogin = (resourceUrl, state, display) =>
//     let
//         AuthorizeUrl = Uri.GetHost(resourceUrl) & "/oauth_auth.do?" & Uri.BuildQueryString([
//             state = state,
//             client_id = client_id,
//             response_type = "code",
//             redirect_uri = redirect_uri
//         ])
//     in
//         [
//             LoginUri = AuthorizeUrl,
//             CallbackUri = redirect_uri,
//             WindowHeight = windowHeight,
//             WindowWidth = windowWidth,
//             Context = resourceUrl
//         ];
// 
// FinishLogin = (resourceUrl, callbackUri, state) =>
//     let
//         parts = Uri.Parts(callbackUri)[Query]
//     in
//         TokenMethod(resourceUrl, "authorization_code", "code", parts[code]);

//token = Text.Range(callbackUri, Text.Length(redirect_uri) + 1),

//     TestConnection = (dataSourcePath) =>
//         let
//             json = Json.Document(dataSourcePath)
//         in
//             { "ServiceNowTableConnector.Contents", json[endpoint], "", "", "", "", "", 10, "", "" }