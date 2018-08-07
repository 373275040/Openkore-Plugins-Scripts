# by alisonrag v1.0
package SakrayAuth;

use strict;
use lib 'C:/strawberry/perl/lib';
use lib 'C:/strawberry/perl/site/lib';
use lib 'C:/strawberry/perl/vendor/lib';
use warnings;
use Globals;
use Plugins;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Headers;
use HTML::Form;
use HTTP::Request::Common qw(POST GET);
use Log qw(message error);
use base qw(Network::Send::Sakray);
use Data::Dumper;

Plugins::register('SakrayAuth', 'kRO Sakray SSO Authenticator', \&unload);

use constant {
	WEBSITE_URL => 'http://ro.gnjoy.com/',
	WEBSITE_LOGIN_URL => 'http://login.gnjoy.com/',
	USER_AGENT => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36'
};

sub unload {
}

sub sendMasterLogin {
	# start necessary variables
	my ($ua, $response, @forms, $input, $headers, $url, $req, $cookie_jar, $current_token);

	# set lwp and http values
	$cookie_jar = HTTP::Cookies->new(autosave => 1, ignore_discard => 1);
	$ua = LWP::UserAgent->new(cookie_jar => $cookie_jar);
	$ua->agent(USER_AGENT);

	# first request to index.php
	$req = GET WEBSITE_URL;
	$response = $ua->request($req);
	$cookie_jar->extract_cookies($response);
	@forms = HTML::Form->parse($response, $response->base);	
    $input = $forms[0]->find_input('__GnjoyRequestVerificationToken');

	# set LWP User Agent and Header to login
	$ua = LWP::UserAgent->new(cookie_jar => $cookie_jar);
	$ua->agent(USER_AGENT);
	$headers = HTTP::Headers->new(
		'Pragma' => 'no-cache',
		'Origin' => 'http//ro.gnjoy.com',
		'Accept-Encoding' => 'gzip, deflate, br',
		'Host' => 'login.gnjoy.com',
		'Accept-Language' => 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
		'Upgrade-Insecure-Requests' => '1',	
		'Content-Type' => 'application/x-www-form-urlencoded',
		'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
		'Cache-Control' => 'no-cache',
		'Referer' => 'http//ro.gnjoy.com/index.asp',
		'Connection' => 'keep-alive'
	);
	$ua->default_headers($headers);

	# try to login
	$url = WEBSITE_LOGIN_URL.'proc/loginproc.asp';
	$req = POST $url, [
		__GnjoyRequestVerificationToken => $input->{value},
		cpflag => 'G',
		loginsubmit => 'N',
		svc => 'G000',
		uid => $config{username},
		upass => $config{password},
		rtnurl => 'http%3A%2F%2Fro%2Egnjoy%2Ecom%2Findex%2Easp'
	];
	$response = $ua->request($req);
	$cookie_jar->extract_cookies($response);	
	$ua->cookie_jar($cookie_jar);
	
	# set Header to reload index page (now index page must come with user infos)
	$headers = HTTP::Headers->new(
		'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
		'Accept-Encoding' => 'gzip, deflate',
		'Accept-Language' => 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
		'Upgrade-Insecure-Requests' => '1',		
		'Connection' => 'keep-alive'
	);
	$ua->default_headers($headers);
	$req = GET WEBSITE_URL;
	$response = $ua->request($req);
	$cookie_jar->extract_cookies($response);	
	$ua->cookie_jar($cookie_jar);

	# set Header and try to emulate Game Execute
	$ua->agent('Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko');
	$headers = HTTP::Headers->new(
		'Host' => 'ro.gnjoy.com',
		'Accept' => 'text/html, application/xhtml+xml, image/jxr, */*',
		'Accept-Encoding' => 'gzip, deflate',
		'Accept-Language' => 'en-US,en;q=0.8,ko;q=0.6,pt-BR;q=0.4,pt;q=0.2',
		'Referer' => 'http://ro.gnjoy.com/index.asp',
		'Upgrade-Insecure-Requests' => '1',
		'Connection' => 'keep-alive'
	);
	$ua->default_headers($headers);
	$url = WEBSITE_URL.'GameExecute/Execute.asp?gamecode=2011';
	$req = GET $url;		
	$response = $ua->request($req);
	$cookie_jar->extract_cookies( $response );
	$ua->cookie_jar($cookie_jar);

	# check if OTT is in cookie
	if($cookie_jar->as_string =~/t1\=(\w+)\&/) {		
		$cookie_jar = HTTP::Cookies->new();
		$headers = HTTP::Headers->new(			
			"Accept" => "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/msword, application/vnd.ms-powerpoint, */*",
			"Accept-Language" => "en-us"			
		);

		$ua = LWP::UserAgent->new(cookie_jar => $cookie_jar, default_headers => $headers, agent => "Mozilla/4.0");
		$url = 'http://start1.gnjoy.com/auth.asp';		
		$req = POST $url, [
			t1 => $1,
			mac => '20-CF-30-95-57-2A',
			gamenum => '2011'
		];
		$req->protocol('HTTP/1.0');
		$response = $ua->request($req);
		$cookie_jar->extract_cookies($response);		
		$current_token = $1;		

		if($response->decoded_content =~/\w+\|(\w+)\|\w+\|\w+\|\w+/) {
			if($1 ne $current_token) { 
				my $master = $masterServers{$config{master}};
				my $len =  length($1) + 92;				
				$messageSender->sendTokenToServer($config{username}, $config{password}, $master->{master_version}, $master->{version}, $1, $len, $master->{ip}, $master->{port});
			}
		}
	
	}
}

*Network::Send::Sakray::sendMasterLogin = *SakrayAuth::sendMasterLogin;

1;
