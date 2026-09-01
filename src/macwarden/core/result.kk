module macwarden/core/result

pub effect abort<x>
  final ctl abort(error : x) : a

pub fun run-result(action : () -> <abort<x>|e> a) : e either<x,a>
  handle action
    return(value) Right(value)
    final ctl abort(error) Left(error)

pub fun require(value : either<x,a>) : abort<x> a
  match value
    Left(error) -> abort(error)
    Right(result) -> result

pub fun require-maybe(value : maybe<a>, error : x) : abort<x> a
  match value
    Nothing -> abort(error)
    Just(result) -> result

pub fun ensure(condition : bool, error : x) : abort<x> ()
  if !condition then abort(error)
