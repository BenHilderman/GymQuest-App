-- Caption length limit (500 chars, matching client-side)
ALTER TABLE public.posts ADD CONSTRAINT posts_caption_length CHECK (char_length(caption) <= 500);

-- Comment content length limit
ALTER TABLE public.comments ADD CONSTRAINT comments_content_length CHECK (char_length(content) <= 1000);

-- Username constraints
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_length CHECK (char_length(username) >= 3 AND char_length(username) <= 30);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_format CHECK (username ~ '^[a-zA-Z0-9_]+$');

-- Display name length
ALTER TABLE public.profiles ADD CONSTRAINT profiles_display_name_length CHECK (char_length(display_name) >= 1 AND char_length(display_name) <= 50);

-- Prevent negative counts
ALTER TABLE public.posts ADD CONSTRAINT posts_like_count_positive CHECK (like_count >= 0);
ALTER TABLE public.posts ADD CONSTRAINT posts_comment_count_positive CHECK (comment_count >= 0);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_follower_count_positive CHECK (follower_count >= 0);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_following_count_positive CHECK (following_count >= 0);

-- Workout duration must be reasonable (0 to 480 minutes / 8 hours)
ALTER TABLE public.workouts ADD CONSTRAINT workouts_duration_range CHECK (duration >= 0 AND duration <= 480);

-- Weight and reps must be non-negative
ALTER TABLE public.exercise_sets ADD CONSTRAINT sets_reps_positive CHECK (reps >= 0);
ALTER TABLE public.exercise_sets ADD CONSTRAINT sets_weight_positive CHECK (weight >= 0);

-- RPE must be 1-10 if provided
ALTER TABLE public.exercise_sets ADD CONSTRAINT sets_rpe_range CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10));

-- Rate limiting: prevent same user from creating more than 20 posts per day
-- Done via a function + trigger
CREATE OR REPLACE FUNCTION check_post_rate_limit() RETURNS trigger AS $$
DECLARE
    post_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO post_count
    FROM public.posts
    WHERE author_id = NEW.author_id
    AND created_at > NOW() - INTERVAL '24 hours';

    IF post_count >= 20 THEN
        RAISE EXCEPTION 'Rate limit exceeded: maximum 20 posts per 24 hours';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER enforce_post_rate_limit
    BEFORE INSERT ON public.posts
    FOR EACH ROW EXECUTE FUNCTION check_post_rate_limit();

-- Rate limit comments: max 100 per day per user
CREATE OR REPLACE FUNCTION check_comment_rate_limit() RETURNS trigger AS $$
DECLARE
    comment_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO comment_count
    FROM public.comments
    WHERE author_id = NEW.author_id
    AND created_at > NOW() - INTERVAL '24 hours';

    IF comment_count >= 100 THEN
        RAISE EXCEPTION 'Rate limit exceeded: maximum 100 comments per 24 hours';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER enforce_comment_rate_limit
    BEFORE INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION check_comment_rate_limit();

-- Rate limit follows: max 50 per day
CREATE OR REPLACE FUNCTION check_follow_rate_limit() RETURNS trigger AS $$
DECLARE
    follow_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO follow_count
    FROM public.follows
    WHERE follower_id = NEW.follower_id
    AND created_at > NOW() - INTERVAL '24 hours';

    IF follow_count >= 50 THEN
        RAISE EXCEPTION 'Rate limit exceeded: maximum 50 follows per 24 hours';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER enforce_follow_rate_limit
    BEFORE INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION check_follow_rate_limit();

-- Prevent self-follow
ALTER TABLE public.follows ADD CONSTRAINT follows_no_self CHECK (follower_id != following_id);
