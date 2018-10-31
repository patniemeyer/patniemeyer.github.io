---
title:  "RxCacheable: Caching and Optimisitic Transformations for RxSwift"
draft: true
---

<p style="font-size: 200%; font-weight: bold; color: red">DRAFT</p>

# RxCacheable: Caching and Optimisitic Transformations for RxSwift

<!--p style="font-size: 75%; font-style: italic">Updated: .</p-->

In this post I'll talk about some caching related extensions that I've used in my RxSwift code. I'm presenting these not so much as a finished project but more to solicit feedback and ideas.  I wasn't able to find a satifsying way to accomplish these tasks using the built-in Rx operators but it's possible that I'm missing something.  Alternately, if anyone thinks these would be useful enough to be polished and wrapped up as proper Traits for RxSwift perhaps we can collaborate.

The issue I'm trying to address here is how to build iOS applications that make frequent asynchronous server calls for data and use it to update a shared local model for the application.  While a pure Rx application might just fetch all of its data in a pristine fashion for every view, this is impractical in most real world mobile apps.  In particular I'm interested in the problem of how to handle local, "optimistic" updates to the data that offer the user immediate feedback for the common case of basic operations.

## CachedSingle

The first utility is essentially just a read-through cache backed by a `Single` data source. New subscriptions prompt an expiration check and new subscribers can be configured to either block waiting for updated data or receive the most recent replay value followed by the update later.

```swift
    CachedSingle<Int>(expiration: 3.0) {
        return Single.create { observer in ... }
            return Disposables.create()
        }
}
```

Repeated calls are coalesced but data is never allowed to get too stale and still only fetched on demand.

### Blocking and Non-blocking

The ability to configure whether or not to block for new data when the cache has expired is desirable in some scenarios: It may be better for your UI to show a spinner for a brief time and then display fresh data rather than always showing stale data followed by an update.  Perhaps you wish to do both, but not make it look like a glitch.

## The Optimistic Problem

Consider a network API for fetching and updating the status of a user: I’m going to make a network call that will attempt to change the status. I'd like to show the change immediately in the client UI (in a consistent way throughout the app) by updating the model locally. Ideally this local change would simply be overwritten by fresh data on the next update from the server.  However what if there is already an update "in-flight" from a previous request? There is an obvious race condition here.

<p align="center"> <img height="350" src="/assets/rxcacheable/updates1.png"> </p>

In fact, there may be multiple race conditions: Some servers offer only "eventual consistency" and so even if we make a call to refresh our data *after* we post our change we could get a stale results for a period of time.  In fact, the more "responsive" we are in updating the UI the more likely we would be to find ourself in that situation.  Either way, there is a chance that an unrelated update could arrive and blow away our data.

A general solution to this problem would require wrapping a transaction around every server call, sending unique ids with the request, pairing up the responses and "committing" the values.  But this would be complicated by individual network calls that may fail and have to be retried or conceivably even return out of order and we'd still have to build our local transform on top of all of this.  

## TransformableCachedSingle

The approach I've taken (for now) is to create a way to apply a simple transformation to the local model and hold it for a period of time.  With this extension I can apply a transform to the user status with the desired intermediate result and then expire the the transformation after a short window of time surrounding the transaction.

<p align="center"> <img height="300" src="/assets/rxcacheable/updates2.png"> </p>

After a specified period of time the transform is expired and no longer applied on the next `Single` production.  An optimistic change is applied to local data and held during the course of a transaction but then allowed to be overwritten when fresh data is demanded later.

```swift
  // TransformableCachedSingle extends CachedSingle
  let cs = TransformableCachedSingle<Int>(expiration: 3.0) { ... }

  // Later apply a transform adding one to the current value.
  let transform: TransformableCachedSingle<Int>.Transform = cs.transform { 
      value in return value + 1 
    }

  // When complete we expire the transform, optionally with a window of time.
  transform.expire(at: date)
```

The transform is applied on top of the underlying cached value, so you can either modify or replace it.  For example when mashing the "like" button on a UI may wish to add 1 to a value.  Alternately maybe you have a UI with an enum of states and one of those states indicates that the value is changing or indeterminate.

<p align="center"> <img height="50" src="/assets/rxcacheable/like.png"> </p>

Why does this matter at all?  You may be thinking that in the case of the "like" button above the user won't know the real count anyway, so why bother?  Well they would definitely notice the differece between a 0 and a 1 :)  Also if the user pushes back from a screen and returns quickly to find their action gone they will be confused.  Worse yet they may end up testing your UI's safeguards by hitting toggle buttons that are in the wrong state.

## Source

As I mentioned, this project is a work in progress.  I'm trying to force myself to release more stuff, 
more often :) All feedback, corrections, suggestions, and pull requests are welcome.

You can find the github project here: <a href="https://github.com/patniemeyer/RxCacheable">RxCacheable</a>. 

## Me

Pat Niemeyer is a Co-founder and software engineer at <a href="https://present.co">Present Company</a>.  He is the author of the Learning Java book series by O'Reilly & Associates and contributor to various open source projects.

{% include nav.html %}

