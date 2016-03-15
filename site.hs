{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Control.Category (id)
import           Control.Monad    (forM_)
import           Data.Monoid      (mappend, mconcat, mempty)
import           Prelude          hiding (id)

import           Hakyll

essayCtx :: Context String
essayCtx = mconcat [modificationTimeField "modified" "%B %e, %Y",
                    dateField "date" "%B %e, %Y",
                    defaultContext]

pageCtx :: String -> Context String
pageCtx title = mconcat [constField "title" title,
                         constField "modified" "unknown",
                         defaultContext]

main :: IO ()
main = hakyllWith config $ do
    -- Compress CSS
    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    -- Copy static files
    match "static/**" $ do
      route   idRoute
      compile copyFileCompiler

    -- Render posts
    match "essays/*" $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/essay.html" essayCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" essayCtx
            >>= relativizeUrls

    -- Render essays list
    create ["essays.html"] $ do
        route idRoute
        compile $ do
          list <- essayList
          let ctx = pageCtx "essays" `mappend` constField "essays" list
          makeItem ""
            >>= loadAndApplyTemplate "templates/essays.html" ctx
            >>= loadAndApplyTemplate "templates/default.html" ctx
            >>= relativizeUrls

    -- Render static pages
    match "index.markdown" $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" (pageCtx "about")
            >>= relativizeUrls
    match "reading.markdown" $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" (pageCtx "reading")
            >>= relativizeUrls
    match "projects.markdown" $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" (pageCtx "projects")
            >>= relativizeUrls

    match "404.markdown" $ do
        route   $ setExtension ".html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" (pageCtx "not-found")
            >>= relativizeUrls

    create ["rss.xml"] $ do
      route idRoute
      compile $ do
        let feedCtx = essayCtx `mappend` bodyField "description"
        posts <- fmap (take 10) . recentFirst =<<
                 loadAllSnapshots "essays/*" "content"
        renderRss myFeedConfiguration feedCtx posts


    -- Read templates
    match "templates/*" $ compile templateCompiler

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "dbp.io :: essays"
    , feedDescription = "writing on programming etc by daniel patterson"
    , feedAuthorName  = "Daniel Patterson"
    , feedAuthorEmail = "dbp@dbpmail.net"
    , feedRoot        = "http://dbp.io"
    }

config = defaultConfiguration
    { deployCommand = "s3cmd -P sync _site/ s3://dbp.io"
    }

essayList :: Compiler (String)
essayList = do
  essays   <- recentFirst =<< loadAll "essays/*"
  itemTpl  <- loadBody "templates/essayitem.html"
  applyTemplateList itemTpl essayCtx essays
