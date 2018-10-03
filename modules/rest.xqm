xquery version "3.0";

(: Syriaca.org restxq file. :)
module namespace api="http://syriaca.org/api";
(: Syriaca.org modules :)
import module namespace global="http://syriaca.org/global" at "lib/global.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace cntneg="http://syriaca.org/cntneg" at "content-negotiation/content-negotiation.xqm";

(:eXist modules:)
import module namespace req="http://exquery.org/ns/request";

(: eXist SPARQL module for SPARQL endpoint, comment out if not using SPARQL module :)
import module namespace sparql="http://exist-db.org/xquery/sparql" at "java:org.exist.xquery.modules.rdf.SparqlModule";

(: For output annotations :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http="http://expath.org/ns/http-client";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(: Establish root directory for restxq :)
declare variable $api:repo {replace($global:app-root, '/db/apps/','')};

(: Establish API endpoints :)


(:
 : Data dump for all records
 : @param $collection filter on collection - see repo-config.xml for collection names
 : @param $format -supported formats rdf/ttl/xml/html/json
 : @param $start
 : @param $limit
 : @param $content-type - serializtion based on format or Content-Type header. 
:)
declare
    %rest:GET
    %rest:path("/e-surayt/api/data")
    %rest:query-param("collection", "{$collection}", "")
    %rest:query-param("format", "{$format}", "")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("limit", "{$limit}", 50)
    %rest:header-param("Content-Type", "{$content-type}")
function api:data-dump(
    $type as xs:string*, 
    $collection as xs:string*, 
    $format as xs:string*, 
    $start as xs:integer*,
    $limit as xs:integer*,
    $content-type as item()*) {
    let $data := if($collection != '') then
                    collection($global:data-root || '/' || $collection)
                 else collection($global:data-root)
    let $request-format := if($format != '') then $format  else if($content-type) then $content-type else 'xml'
    return cntneg:content-negotiation(subsequence($data, $start, $limit), $request-format,())
};

(:
 : Data dump for any results set may be posted to this endpoint for serialization
 : @param $content-type - serializtion based on format or Content-Type header. 
:)
declare
    %rest:POST('{$data}')
    %rest:path('/e-surayt/api/data/serialize')
    %rest:header-param("Content-Type", "{$content-type}")
function api:data-serialize($data as item()*, $content-type as item()*) {
   cntneg:content-negotiation($data, $content-type,())
};

(:~
  : Use resxq to for content negotiation
  : @param $folder syriaca.org subcollection 
  : @param $page record id
  : @note extension is passed in with $page parameter, parsed out after .
  :)
declare
    %rest:GET
    %rest:path("/e-surayt/{$page}")
    %rest:header-param("Content-Type", "{$content-type}")
function api:get-page($page as xs:string?, $content-type as item()*) {
    let $path := concat('/',$page)      
    return  
        let $id :=  if(contains($page,'.')) then
                            concat($global:get-config//repo:collection[1]/@record-URI-pattern,substring-before($page,"."))
                        else concat($global:get-config//repo:collection[1]/@record-URI-pattern,$page)
        let $data := if(api:get-tei($id) != '') then api:get-tei($id) else api:not-found($id)
        return cntneg:content-negotiation($data, $content-type, $path) 
};

(:~
  : Use resxq to for content negotiation
  : @param $folder syriaca.org subcollection 
  : @param $page record id
  : @param $extension record extension
  :)
declare
    %rest:GET
    %rest:path("/e-surayt/{$page}/{$extension}")
    %rest:header-param("Content-Type", "{$content-type}")
function api:get-page($page as xs:string?, $extension as xs:string, $content-type as item()*) {
    let $path := concat('/',$page,'.',$extension)
    return  
            let $id :=  if(contains($page,'.')) then
                            concat($global:get-config//repo:collection[1]/@record-URI-pattern,substring-before($page,"."))
                        else concat($global:get-config//repo:collection[1]/@record-URI-pattern,$page)
            let $data := if(api:get-tei($id) != '') then api:get-tei($id) else api:not-found($id)
            return cntneg:content-negotiation($data, $extension, ()) 
}; 

(: Helper functions :)

(: Function to generate a 404 Not found response 
response:redirect-to()
:)
declare function api:not-found($path as xs:string?){
  (<rest:response>
    <http:response status="404" message="Not found.">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Content-Type" value="text/html; charset=utf-8"/>
    </http:response>
  </rest:response>,
  <path>{$path}</path>
  (:<rest:forward>{ xs:anyURI(concat($global:nav-base, '/404.html')) }</rest:forward>:)
  )
};

(:~
 : Get TEI record based on $id
 : Builds full uri based on repo.xml
:)
declare function api:get-tei($id){
    root(collection($global:data-root)//tei:idno[. = $id])
};
