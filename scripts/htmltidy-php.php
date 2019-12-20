#!/usr/bin/env php
<?php

function get_filebuffer()
{
    if($_SERVER['argc'] > 1)
    {
        return file_get_contents($_SERVER['argv'][1]);
    }
    return file_get_contents("php://stdin");
};

$encoding = 'utf8';
$options =
[
/*
    'hide-comments'       => false,
    'tidy-mark'           => false,
    'indent'              => true,
    'indent-spaces'       => 4,
    'new-blocklevel-tags' => 'article,header,footer,section,nav',
    'new-inline-tags'     => 'video,audio,canvas,ruby,rt,rp',
    'new-empty-tags'      => 'source',
    'doctype'             => '<!DOCTYPE HTML>',
    'sort-attributes'     => 'alpha',
    'vertical-space'      => false,
    'output-xhtml'        => true,
    'wrap'                => 180,
    'wrap-attributes'     => false,
    'break-before-br'     => false,
    */
    'anchor-as-name' => false,
    'break-before-br' => true,
    'char-encoding' => $encoding,
    'decorate-inferred-ul' => false,
    'doctype' => 'omit',
    'drop-empty-paras' => false,
    'drop-font-tags' => true,
    'drop-proprietary-attributes' => false,
    'force-output' => true,
    'hide-comments' => false,
    'indent' => true,
    'indent-attributes' => false,
    'indent-spaces' => 4,
    'input-encoding' => $encoding,
    'join-styles' => false,
    'logical-emphasis' => false,
    'merge-divs' => false,
    'merge-spans' => false,
    'new-blocklevel-tags' => 'article aside audio bdi canvas details dialog figcaption figure footer header hgroup main menu menuitem nav section source summary template track video',
    'new-empty-tags' => 'command embed keygen source track wbr',
    'new-inline-tags' => 'audio command datalist embed keygen mark menuitem meter output progress source time video wbr',
    'newline' => 0,
    'numeric-entities' => false,
    'output-bom' => false,
    'output-encoding' => $encoding,
    'output-html' => true,
    'preserve-entities' => true,
    'quiet' => true,
    'quote-ampersand' => true,
    'quote-marks' => false,
    'repeated-attributes' => 1,
    'show-body-only' => false,
    'show-warnings' => true,
    'sort-attributes' => 1,
    'tab-size' => 4,
    'tidy-mark' => false,
    'vertical-space' => true,
    'wrap' => 0,
];


$filebuf = get_filebuffer();
$tidybuf = tidy_parse_string($filebuf, $options, 'utf8');
tidy_clean_repair($tidybuf);
// Fix a tidy doctype bug
#$tidybuf = str_replace('<html lang="en" xmlns="http://www.w3.org/1999/xhtml">', '<!DOCTYPE HTML>', $tidybuf);
print($tidybuf);
print("\n");
#var_export($tidybuf);
